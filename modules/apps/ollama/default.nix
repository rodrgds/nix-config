{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.ollama;
  isDarwin = pkgs.stdenv.isDarwin;
  isLinux = pkgs.stdenv.isLinux;
  ollamaPkg = if isDarwin then pkgs.ollama else pkgs.ollama-cuda;
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
      {
        environment.systemPackages = [ ollamaPkg ];
      }
      (lib.optionalAttrs isLinux {
        services.ollama = {
          enable = true;
          package = ollamaPkg;
          host = cfg.host;
          port = cfg.port;
          loadModels = cfg.loadModels;
          environmentVariables = cfg.environmentVariables;
        };
      })
      (lib.optionalAttrs isDarwin {
        launchd.user.agents.ollama = {
          path = [ config.environment.systemPath ];
          serviceConfig = {
            KeepAlive = true;
            RunAtLoad = true;
            ProgramArguments = [
              "${ollamaPkg}/bin/ollama"
              "serve"
            ];
            EnvironmentVariables = cfg.environmentVariables // {
              OLLAMA_HOST = "${cfg.host}:${toString cfg.port}";
            };
          };
        };
      })
    ]
  );
}
