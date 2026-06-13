{
  lib,
  config,
  pkgs,
  constants,
  ...
}:
let
  cfg = config.apps.ollama;
  inherit (constants) isDarwin isLinux homeDir;
  ollamaPkg = pkgs.ollama-cuda;
in
{
  options.apps.ollama = {
    enable = lib.mkEnableOption "Enable Ollama local LLM runner";
    loadModels = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "List of Ollama models to preload on service start";
    };
    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Host address for the Ollama server.";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 11434;
      description = "Port for the Ollama server.";
    };
    environmentVariables = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Extra environment variables for the Ollama service.";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        services.ollama = {
          enable = true;
          package = ollamaPkg;
          inherit (cfg)
            host
            port
            loadModels
            environmentVariables
            ;
        };

        # Work around intermittent Ollama key corruption that causes:
        # "pull model manifest: ssh: no key found"
        # If keys are invalid, remove them before startup so Ollama regenerates.
        systemd.services.ollama.preStart = ''
          keyDir=/var/lib/ollama/.ollama
          priv="$keyDir/id_ed25519"
          pub="$keyDir/id_ed25519.pub"

          mkdir -p "$keyDir"

          bad=0
          if [ -e "$priv" ] && ! ${pkgs.openssh}/bin/ssh-keygen -l -f "$priv" >/dev/null 2>&1; then
            bad=1
          fi

          if [ -e "$pub" ] && ! ${pkgs.openssh}/bin/ssh-keygen -l -f "$pub" >/dev/null 2>&1; then
            bad=1
          fi

          if [ "$bad" -eq 1 ]; then
            rm -f "$priv" "$pub"
          fi
        '';
      })
      (lib.optionalAttrs isDarwin {
        homebrew.casks = [ "ollama-app" ];

        launchd.user.agents.ollama = {
          serviceConfig = {
            Label = "com.user.ollama";
            KeepAlive = true;
            RunAtLoad = true;
            ProgramArguments = [
              "/opt/homebrew/bin/ollama"
              "serve"
            ];
            EnvironmentVariables = cfg.environmentVariables // {
              OLLAMA_HOST = "${cfg.host}:${toString cfg.port}";
            };
            StandardOutPath = "/tmp/ollama.log";
            StandardErrorPath = "/tmp/ollama.error.log";
          };
        };
      })
    ]
  );
}
