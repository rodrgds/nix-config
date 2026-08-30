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
  piLauncherPath = "${constants.homeDir}/.local/bin/pi";

  nineRouterCatalog = import ../../shared/9router.nix;

  gnhfConfig = ''
    agent: pi

    agentPathOverride:
      pi: ${piLauncherPath}

    commitMessage:
      preset: conventional

    maxConsecutiveFailures: 3
    preventSleep: true
  '';

  managedPackages = [
    "npm:pi-web-access"
    "npm:@howaboua/pi-codex-conversion"
    "npm:@howaboua/pi-cache-hit-predictor"
    "npm:pi-powerline-footer"
    "npm:pi-copy-all"
    "npm:pi-codex-goal"
    "npm:@narumitw/pi-btw"
    "npm:pi-context-view"
    "npm:@luxusai/pi-hindsight"
    "npm:pi-mcp-adapter"
    "npm:pi-annotate"
    "npm:pi-image-paste"
    "npm:@saadjs/pi-stash"
    "npm:pi-subagents"
  ];
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
      default = lib.optionalAttrs isDarwin {
        "app.clipboard.pasteImage" = [
          "ctrl+v"
          "super+v"
        ];
      };
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
        hindsightApiTokenPath = config.sops.secrets.hindsight_api_token.path;

        piSettings = lib.recursiveUpdate {
          # Plain npm. The global prefix comes from the managed ~/.npmrc so
          # Pi's local installs (git package dependency installs run as plain
          # `npm install` in the package dir) resolve their own package.json
          # instead of the global root. A --prefix here would break those.
          npmCommand = [ toolchain.npm.binPath ];

          shellPath = "${pkgs.bash}/bin/bash";

          defaultProvider = "openai-codex";
          defaultModel = "gpt-5.6-sol";
          defaultThinkingLevel = "high";
          enabledModels = (map (model: "nine_router/${model.alias}") nineRouterCatalog.models) ++ [
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

        hindsightConfig = builtins.toJSON {
          enabled = true;
          setupComplete = true;
          agentUse = "coding";
          hindsight = {
            baseUrl = "http://rgo-nas:8888";
            apiKey = {
              source = "env";
              name = "HINDSIGHT_API_TOKEN";
            };
            timeoutMs = 40000;
          };
          banks = {
            project = {
              enabled = false;
              derive = "manual";
            };
            user = {
              enabled = true;
              bankId = "rodrigo";
            };
          };
          recall = {
            enabled = true;
            budget = "mid";
            maxTokens = 1200;
            userMaxTokens = 1200;
            types = [
              "observation"
              "world"
              "experience"
            ];
            includeSourceFacts = false;
            includeRepoHintsInQuery = true;
            preferObservations = true;
          };
          retain.enabled = false;
          userRetain.mode = "explicit-only";
          notifications = {
            startup = true;
            recall = false;
            retain = false;
          };
        };

        mcpConfig = builtins.toJSON {
          settings = {
            toolPrefix = "short";
            hostConfigDiscovery = "off";
            notifyOnStartupConnect = false;
            mcpFooterStatus = "compact";
          };
          mcpServers.executor = {
            url = "https://executor.sh/rodrigo-dias/mcp";
            auth = "oauth";
            lifecycle = "lazy-keep-alive";
            directTools = true;
            protocolVersion = "legacy";
          };
        };

        codexConversionConfig = builtins.toJSON {
          voice.serverShortcut = "ctrl+alt+v";
        };
      in
      lib.mkMerge [
        {
          # The shared npm prefix also contains an unwrapped `pi` binary. Keep
          # this directory first so interactive shells use the launcher below,
          # which loads runtime-only secrets before handing off to npm.
          home.sessionPath = lib.mkBefore [ "${constants.homeDir}/.local/bin" ];

          sops.secrets = {
            nine_router_api_key = { };
            exa_api_key = { };
            opencode_go_api_key = { };
            hindsight_api_token.sopsFile = ../../../secrets/hindsight-secrets.yaml;
          };

          home.packages = [
            pkgs.ripgrep
            pkgs.fd
          ];

          home.file = {
            ".gnhf/config.yml".text = gnhfConfig;
            ".pi/agent/settings.json".text = builtins.toJSON piSettings;
            ".pi/agent/models.json".text = builtins.toJSON piModels;
            ".pi/agent/hindsight.json".text = hindsightConfig;
            ".pi/agent/mcp.json".text = mcpConfig;
            ".pi/agent/keybindings.json".text = builtins.toJSON cfg.keybindings;
            ".pi/agent/pi-codex-conversion.json".text = codexConversionConfig;
            ".config/pi/web-search.json".text = webSearchConfig;
            ".pi/web-search.json".text = webSearchConfig;
            ".local/bin/pi" = {
              executable = true;
              text = ''
                #!${pkgs.bash}/bin/bash
                set -euo pipefail
                export HINDSIGHT_API_TOKEN="$(${pkgs.coreutils}/bin/cat ${lib.escapeShellArg hindsightApiTokenPath})"
                exec ${lib.escapeShellArg "${toolchain.npm.binDir}/pi"} "$@"
              '';
            };
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
