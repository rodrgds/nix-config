{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.pi;
  inherit (constants) isDarwin isLinux;
  toolchain = config.apps.javascript-toolchain;
  packageName = "@earendil-works/pi-coding-agent";

  nineRouterCatalog = import ../../shared/9router.nix;

  gnhfConfig = ''
    agent: pi

    agentPathOverride:
      pi: ${toolchain.npm.binDir}/pi

    commitMessage:
      preset: conventional

    maxConsecutiveFailures: 3
    preventSleep: true
  '';

  managedPackages = [
    "npm:pi-web-access"
    "npm:pi-commandcode-provider"
    "npm:pi-powerline-footer"
    "npm:pi-copy-all"
    "npm:@narumitw/pi-goal"
    "npm:@narumitw/pi-btw"
    "npm:@agnishc/edb-context-viewer"
    # Codex-style OpenAI server-side compaction for openai/* and openai-codex/*
    # models. Experimental; mirrors how codex uses the Responses compaction v2
    # protocol. Self-updates from repo HEAD via `pi update --extensions`.
    "git:github.com/algal/pi-openai-server-compaction"
  ];

  # Config for the pi-openai-server-compaction extension. Matches the
  # extension's documented defaults; kept here so it is tunable in the repo.
  openaiServerCompactionConfig = builtins.toJSON {
    enabled = true;
    includeAzure = false;
    compactThreshold = 0;
    thresholdRatio = 0.7;
    usePreviousResponseId = true;
    notify = false;
  };
in
{
  options.apps.pi = {
    enable = lib.mkEnableOption "Enable Pi";

    nineRouter.baseURL = lib.mkOption {
      type = lib.types.str;
      default = "http://rgo-nas:20128/v1";
      description = "9Router OpenAI-compatible endpoint.";
    };

    packages = lib.mkOption {
      type = lib.types.listOf lib.types.anything;
      default = [ ];
      description = "Declaratively configured Pi npm/git/local package sources.";
    };

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Additional Pi settings merged into this module's defaults.";
    };

    keybindings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Declarative Pi keybindings.";
    };
  };

  config = lib.mkIf cfg.enable {
    apps.javascript-toolchain = {
      enable = true;
      npm.cliPackages = {
        pi = {
          package = "${packageName}@latest";
          bootstrapFiles = [ "lib/node_modules/@earendil-works/pi-coding-agent/package.json" ];
          retiredPackages = [ "@mariozechner/pi-coding-agent" ];
          postUpdate = [
            ''
              rpc_client="$install_root/lib/node_modules/@earendil-works/pi-coding-agent/dist/modes/rpc/rpc-client.js"
              if [ -f "$rpc_client" ]; then
                sed -i -e 's/spawn("node",/spawn(process.execPath,/g' "$rpc_client" || true
              fi

              if [ -x "$install_root/bin/pi" ]; then
                "$install_root/bin/pi" update --extensions
              fi

              if [ -f "$rpc_client" ]; then
                sed -i -e 's/spawn("node",/spawn(process.execPath,/g' "$rpc_client" || true
              fi
            ''
          ];
        };
        gnhf.package = "gnhf@latest";
      };
    };

    # Essential CLI tools for pi.
    environment.systemPackages = [
      pkgs.ripgrep
      pkgs.fd
    ];

    # Keep GUI tools able to resolve them.
    home-manager.users.${username} =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        nineRouterApiKeyPath = config.sops.secrets.nine_router_api_key.path;
        exaApiKeyPath = config.sops.secrets.exa_api_key.path;
        opencodeGoApiKeyPath = config.sops.secrets.opencode_go_api_key.path;

        piSettings = lib.recursiveUpdate {
          # Plain npm. The global prefix comes from the managed ~/.npmrc so
          # Pi's local installs (git package dependency installs run as plain
          # `npm install` in the package dir) resolve their own package.json
          # instead of the global root. A --prefix here would break those.
          npmCommand = [ toolchain.npm.binPath ];

          shellPath = "${pkgs.bash}/bin/bash";

          defaultProvider = "opencode-go";
          defaultModel = "muse-spark-1.2-contributor";
          defaultThinkingLevel = "high";
          enabledModels = [
            "commandcode/xiaomi/mimo-v2.5-pro"
          ]
          ++ (map (model: "nine_router/${model.alias}") nineRouterCatalog.models)
          ++ [
            "opencode/x-preview-f-free"
            "opencode-go/muse-spark-1.2-contributor"
            "openai-codex/gpt-5.6-luna"
            "openai-codex/gpt-5.6-sol"
          ];

          defaultProjectTrust = "ask";
          enableInstallTelemetry = false;
          enableSkillCommands = true;

          theme = "flexoki";
          themes = [ "themes" ];
          extensions = [ "extensions" ];
          prompts = [ "prompts" ];

          powerline = {
            preset = "default";
            placement = "above";
            welcome = false;
            path.mode = "basename";
            model.display = "name";
            git.hostIcon = true;
            customItems = [
              {
                id = "gnhf";
                statusKey = "gnhf";
                position = "right";
                prefix = "gnhf";
                color = "accent";
              }
            ];
          };

          retry = {
            enabled = true;
            maxRetries = 3;
            baseDelayMs = 2000;
            provider = {
              maxRetries = 0;
              maxRetryDelayMs = 60000;
            };
          };

          packages = managedPackages ++ cfg.packages;
        } cfg.settings;

        piModels = {
          providers.nine_router = {
            baseUrl = cfg.nineRouter.baseURL;
            api = "openai-completions";
            apiKey = "!${pkgs.coreutils}/bin/cat ${nineRouterApiKeyPath}";
            models = map (
              model:
              {
                id = model.alias;
                name = model.displayName;
              }
              // (model.pi or { })
            ) nineRouterCatalog.models;
          };

          # OpenCode Go subscription. muse-spark-1.2-contributor is served
          # through the Responses API (/v1/responses); declare it explicitly
          # so the built-in opencode-go model list does not need to carry it.
          providers.opencode-go = {
            baseUrl = "https://opencode.ai/zen/go/v1";
            api = "openai-responses";
            apiKey = "!${pkgs.coreutils}/bin/cat ${opencodeGoApiKeyPath}";
            models = [
              {
                id = "muse-spark-1.2-contributor";
                name = "Muse Spark 1.2 Contributor";
                reasoning = true;
                input = [
                  "text"
                  "image"
                ];
                contextWindow = 1048576;
                maxTokens = 131072;
                cost = {
                  input = 0.10;
                  output = 0.20;
                  cacheRead = 0.002;
                  cacheWrite = 0;
                };
              }
            ];
          };

          # Ox Alpha (0x) free stealth model via OpenCode Zen (`x-preview-f-free`).
          # Endpoint: https://opencode.ai/zen/v1/chat/completions (openai-completions).
          # Reuses the same OpenCode Zen API key as opencode-go. Free, zero-retention.
          providers.opencode = {
            apiKey = "!${pkgs.coreutils}/bin/cat ${opencodeGoApiKeyPath}";
            models = [
              {
                id = "x-preview-f-free";
                name = "Ox Alpha Free (0x)";
                api = "openai-completions";
                reasoning = true;
                input = [
                  "text"
                  "image"
                ];
                contextWindow = 1048576;
                maxTokens = 131072;
                cost = {
                  input = 0;
                  output = 0;
                  cacheRead = 0;
                  cacheWrite = 0;
                };
                compat = {
                  supportsStore = false;
                  supportsDeveloperRole = false;
                  maxTokensField = "max_tokens";
                };
              }
            ];
          };
        };

        # pi-web-access resolves its web-search config to
        # $XDG_CONFIG_HOME/pi/web-search.json (Linux, where XDG_CONFIG_HOME
        # is set) or ~/.pi/web-search.json (Darwin fallback). Manage both so
        # the Exa key is found regardless of the runtime environment.
        webSearchConfig = builtins.toJSON {
          provider = "exa";
          # Return results to the agent directly instead of opening the
          # interactive curator browser. Alternatives: "summary-review"
          # (curator, default) or "auto-summary" (AI summary, no browser).
          workflow = "none";
          exaApiKey = "!${pkgs.coreutils}/bin/cat ${exaApiKeyPath}";
        };
      in
      lib.mkMerge [
        {
          sops.secrets = {
            nine_router_api_key = { };
            exa_api_key = { };
            opencode_go_api_key = { };
          };

          home.packages = [
            pkgs.ripgrep
            pkgs.fd
          ];

          home.file = {
            ".gnhf/config.yml".text = gnhfConfig;
            ".pi/agent/settings.json".text = builtins.toJSON piSettings;
            ".pi/agent/models.json".text = builtins.toJSON piModels;
            ".pi/agent/keybindings.json".text = builtins.toJSON cfg.keybindings;
            ".pi/agent/openai-server-compaction.json".text = openaiServerCompactionConfig;
            ".config/pi/web-search.json".text = webSearchConfig;
            ".pi/web-search.json".text = webSearchConfig;
            ".pi/agent/themes/flexoki.json".text = builtins.toJSON (
              import ./_data/flexoki-theme.nix {
                inherit (constants) colors;
              }
            );
            ".pi/agent/extensions/powerline-footer/theme.json".text = builtins.toJSON (
              import ./_data/powerline-theme.nix {
                inherit (constants) colors;
              }
            );
            ".pi/agent/extensions" = {
              source = ./resources/extensions;
              recursive = true;
            };
            ".pi/agent/prompts" = {
              source = ./resources/prompts;
              recursive = true;
            };
          };
        }
      ];
  };
}
