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

  litellmCatalog = import ../../shared/litellm.nix;

  managedGlobalNpmPackages = [
    "${packageName}@latest"
  ];

  managedPackages = [
    "npm:pi-web-access"
    "npm:pi-subagents"
    "npm:pi-commandcode-provider"
    "npm:pi-powerline-footer"
    "npm:pi-copy-all"
    "npm:@narumitw/pi-goal"
    "npm:@narumitw/pi-btw"
    "npm:@agnishc/edb-context-viewer"
  ];

  updateScript = pkgs.writeShellApplication {
    name = "update-pi-cli";

    runtimeInputs = [
      pkgs.coreutils
      pkgs.git
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
        gnhf \
        >/dev/null 2>&1 || true

      npm install \
        --global \
        --prefix "$install_root" \
        --ignore-scripts \
        --no-audit \
        --no-fund \
        ${lib.concatStringsSep " " managedGlobalNpmPackages}

      # Update declaratively configured, unpinned Pi packages without changing
      # Home Manager-owned settings.json.
      if [ -x "$install_root/bin/pi" ]; then
        "$install_root/bin/pi" update --extensions
      fi
    '';
  };
in
{
  options.apps.pi = {
    enable = lib.mkEnableOption "Enable Pi";

    litellm.baseURL = lib.mkOption {
      type = lib.types.str;
      default = "http://rgo-vps:4000/v1";
      description = "LiteLLM OpenAI-compatible endpoint.";
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
        litellmMasterKeyPath = config.sops.secrets.litellm_master_key.path;
        exaApiKeyPath = config.sops.secrets.exa_api_key.path;

        piSettings = lib.recursiveUpdate {
          npmCommand = [
            "${pkgs.nodejs}/bin/npm"
            "--prefix"
            installRoot
          ];

          shellPath = "${pkgs.bash}/bin/bash";

          defaultProvider = "commandcode";
          defaultModel = "xiaomi/mimo-v2.5-pro";
          defaultThinkingLevel = "high";
          enabledModels = [
            "commandcode/xiaomi/mimo-v2.5-pro"
          ]
          ++ (map (model: "litellm/${model.alias}") litellmCatalog.models)
          ++ [
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
          providers.litellm = {
            baseUrl = cfg.litellm.baseURL;
            api = "openai-completions";
            apiKey = "!${pkgs.coreutils}/bin/cat ${litellmMasterKeyPath}";
            models = map (
              model:
              {
                id = model.alias;
                name = model.displayName;
              }
              // (model.pi or { })
            ) litellmCatalog.models;
          };
        };
      in
      lib.mkMerge [
        {
          home.packages = [
            pkgs.ripgrep
            pkgs.fd
            updateScript
          ];

          home.sessionPath = [ "$HOME/${installDir}/bin" ];

          # Bootstrap only when Pi is absent, or when migrating package names;
          # routine updates happen through the scheduled updater.
          home.activation.installPiCli = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            if [ ! -x "$HOME/${installDir}/bin/pi" ] || \
               [ ! -f ${lib.escapeShellArg packagePath} ]; then
              ${updateScript}/bin/update-pi-cli
            fi
          '';

          home.file = {
            ".pi/agent/settings.json".text = builtins.toJSON piSettings;
            ".pi/agent/models.json".text = builtins.toJSON piModels;
            ".pi/agent/keybindings.json".text = builtins.toJSON cfg.keybindings;
            ".pi/agent/AGENTS.md".source = ./_data/global-agents.md;
            ".pi/web-search.json".text = builtins.toJSON {
              exaApiKey = "!${pkgs.coreutils}/bin/cat ${exaApiKeyPath}";
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

        (lib.optionalAttrs isLinux {
          systemd.user.services.update-pi-cli = {
            Unit.Description = "Update Pi from npm";
            Service = {
              Type = "oneshot";
              ExecStart = "${updateScript}/bin/update-pi-cli";
              Nice = 10;
              IOSchedulingClass = "idle";
            };
          };

          systemd.user.timers.update-pi-cli = {
            Unit.Description = "Periodically update Pi";
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
