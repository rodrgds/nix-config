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

  installDir = ".local/share/npm-global";
  installRoot = "${constants.homeDir}/${installDir}";
  packageName = "@earendil-works/pi-coding-agent";
  packagePath = "${installRoot}/lib/node_modules/@earendil-works/pi-coding-agent/package.json";

  nineRouterCatalog = import ../../shared/9router.nix;

  managedGlobalNpmPackages = [
    "${packageName}@latest"
    "gnhf@latest"
  ];

  gnhfConfig = ''
    agent: pi

    agentPathOverride:
      pi: ${installRoot}/bin/pi

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

  updateScript = pkgs.writeShellApplication {
    name = "update-pi-cli";

    runtimeInputs = [
      pkgs.coreutils
      pkgs.git
      pkgs.gnused
      pkgs.nodejs
    ];

    text = ''
      install_root=${lib.escapeShellArg installRoot}
      mkdir -p "$install_root"

      # Remove retired packages after migration.
      npm uninstall \
        --global \
        --prefix "$install_root" \
        @mariozechner/pi-coding-agent \
        >/dev/null 2>&1 || true

      npm install \
        --global \
        --prefix "$install_root" \
        --ignore-scripts \
        --no-audit \
        --no-fund \
        ${lib.concatStringsSep " " managedGlobalNpmPackages}

      # Paseo launches with minimal PATH (/usr/bin:/bin:/usr/sbin:/sbin) so
      # `env node` shebangs fail. The Nix-managed paseo provider now invokes
      # pi via absolute node, but pi's own rpc-client still does
      # spawn("node", ...) which needs PATH. Patch it to use
      # process.execPath so it works regardless of PATH; reapply after
      # every update until upstream fixes it.
      rpc_client="$install_root/lib/node_modules/@earendil-works/pi-coding-agent/dist/modes/rpc/rpc-client.js"
      if [ -f "$rpc_client" ]; then
        sed -i -e 's/spawn("node",/spawn(process.execPath,/g' "$rpc_client" || true
      fi

      # Update declaratively configured, unpinned Pi packages without changing
      # Home Manager-owned settings.json.
      if [ -x "$install_root/bin/pi" ]; then
        "$install_root/bin/pi" update --extensions
      fi

      # Reapply after `pi update --extensions` which may reinstall Pi.
      if [ -f "$rpc_client" ]; then
        sed -i -e 's/spawn("node",/spawn(process.execPath,/g' "$rpc_client" || true
      fi
    '';
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
    apps.nodejs.enable = true;

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
          npmCommand = [ "${pkgs.nodejs}/bin/npm" ];

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
            updateScript
          ];

          home.sessionPath = [ "$HOME/${installDir}/bin" ];

          # Bootstrap only when Pi or GNHF is absent, or when migrating package
          # names; routine updates happen through the scheduled updater.
          home.activation.installPiCli = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            if [ ! -x "$HOME/${installDir}/bin/pi" ] || \
               [ ! -x "$HOME/${installDir}/bin/gnhf" ] || \
               [ ! -f ${lib.escapeShellArg packagePath} ]; then
              ${updateScript}/bin/update-pi-cli
            fi
          '';

          home.file = {
            ".npmrc".text = "prefix=${installRoot}\n";
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

        (lib.optionalAttrs isLinux {
          systemd.user.services.update-pi-cli = {
            Unit.Description = "Update Pi and GNHF from npm";
            Service = {
              Type = "oneshot";
              ExecStart = "${updateScript}/bin/update-pi-cli";
              Nice = 10;
              IOSchedulingClass = "idle";
            };
          };

          systemd.user.timers.update-pi-cli = {
            Unit.Description = "Periodically update Pi and GNHF";
            Timer = {
              OnBootSec = "15m";
              OnUnitActiveSec = "1d";
              RandomizedDelaySec = "1h";
              Persistent = true;
            };
            Install.WantedBy = [ "timers.target" ];
          };
        })

        (lib.optionalAttrs isDarwin {
          launchd.agents.update-pi-cli = {
            enable = true;
            config = {
              Label = "pt.rgo.update-pi-cli";
              ProgramArguments = [ "${updateScript}/bin/update-pi-cli" ];
              StartCalendarInterval = lib.hm.darwin.mkCalendarInterval "daily";
              ProcessType = "Background";
              LowPriorityIO = true;
              StandardOutPath = "/tmp/update-pi-cli.log";
              StandardErrorPath = "/tmp/update-pi-cli.err";
              EnvironmentVariables = {
                HOME = constants.homeDir;
              };
            };
          };
        })
      ];
  };
}
