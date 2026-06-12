# LiteLLM OpenAI-compatible LLM router/load balancer
# Routes requests across multiple API keys with failover.
# Uses separate upstream bases:
#   zenApiBase — OpenCode Zen  (openai-compatible, free models)
#   goApiBase  — OpenCode Go   (openai + anthropic compatible, paid models)
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.vps.litellm;
  yaml = pkgs.formats.yaml { };
in
{
  options.vps.litellm = {
    enable = lib.mkEnableOption "LiteLLM OpenAI-compatible LLM router";

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address LiteLLM should bind to. Keep localhost unless exposing through Caddy/Tailscale.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 4000;
      description = "LiteLLM proxy port.";
    };

    zenApiBase = lib.mkOption {
      type = lib.types.str;
      default = "https://opencode.ai/zen/v1";
      description = "OpenCode Zen API base URL (OpenAI-compatible, free models).";
    };

    goApiBase = lib.mkOption {
      type = lib.types.str;
      default = "https://opencode.ai/zen/go/v1";
      description = "OpenCode Go API base URL (OpenAI-compatible models).";
    };

    goAnthropicBase = lib.mkOption {
      type = lib.types.str;
      default = "https://opencode.ai/zen/go";
      description = "OpenCode Go base URL for Anthropic-compatible models (LiteLLM appends /v1/messages).";
    };

    flashFreeModel = lib.mkOption {
      type = lib.types.str;
      default = "openai/deepseek-v4-flash-free";
      description = "Upstream model slug for the free DeepSeek V4 Flash route (Zen).";
    };

    flashPaidModel = lib.mkOption {
      type = lib.types.str;
      default = "openai/deepseek-v4-flash";
      description = "Upstream model slug for the paid/normal DeepSeek V4 Flash route (Go).";
    };

    normalModel = lib.mkOption {
      type = lib.types.str;
      default = "anthropic/minimax-m3";
      description = "Upstream model slug for MiniMax M3 (Go, Anthropic-compatible /messages endpoint).";
    };

    cooldownTime = lib.mkOption {
      type = lib.types.int;
      default = 3600;
      description = "Seconds to keep a failed/exhausted key in cooldown.";
    };
  };

  config = lib.mkIf cfg.enable {
    sops.templates."litellm.env" = {
      owner = "root";
      group = "root";
      mode = "0400";
      content = ''
        LITELLM_MASTER_KEY=${config.sops.placeholder.litellm_master_key}

        OPENCODE_KEY_1=${config.sops.placeholder.litellm_opencode_key_1}
        OPENCODE_KEY_2=${config.sops.placeholder.litellm_opencode_key_2}
        OPENCODE_KEY_3=${config.sops.placeholder.litellm_opencode_key_3}
        OPENCODE_KEY_4=${config.sops.placeholder.litellm_opencode_key_4}
      '';
    };

    environment.etc."litellm/config.yaml" = {
      source = yaml.generate "litellm-config.yaml" {
        model_list = [
          # Public model: flash (DeepSeek V4 Flash Free via Zen, then paid via Go)
          {
            model_name = "flash";
            litellm_params = {
              model = cfg.flashFreeModel;
              api_base = cfg.zenApiBase;
              api_key = "os.environ/OPENCODE_KEY_1";
            };
          }

          {
            model_name = "flash-free-key-2";
            litellm_params = {
              model = cfg.flashFreeModel;
              api_base = cfg.zenApiBase;
              api_key = "os.environ/OPENCODE_KEY_2";
            };
          }

          {
            model_name = "flash-free-key-3";
            litellm_params = {
              model = cfg.flashFreeModel;
              api_base = cfg.zenApiBase;
              api_key = "os.environ/OPENCODE_KEY_3";
            };
          }

          {
            model_name = "flash-free-key-4";
            litellm_params = {
              model = cfg.flashFreeModel;
              api_base = cfg.zenApiBase;
              api_key = "os.environ/OPENCODE_KEY_4";
            };
          }

          {
            model_name = "flash-paid-key-1";
            litellm_params = {
              model = cfg.flashPaidModel;
              api_base = cfg.goApiBase;
              api_key = "os.environ/OPENCODE_KEY_1";
            };
          }

          {
            model_name = "flash-paid-key-2";
            litellm_params = {
              model = cfg.flashPaidModel;
              api_base = cfg.goApiBase;
              api_key = "os.environ/OPENCODE_KEY_2";
            };
          }

          {
            model_name = "flash-paid-key-3";
            litellm_params = {
              model = cfg.flashPaidModel;
              api_base = cfg.goApiBase;
              api_key = "os.environ/OPENCODE_KEY_3";
            };
          }

          {
            model_name = "flash-paid-key-4";
            litellm_params = {
              model = cfg.flashPaidModel;
              api_base = cfg.goApiBase;
              api_key = "os.environ/OPENCODE_KEY_4";
            };
          }

          # Public model: normal (MiniMax M3 via Go, Anthropic-compatible)
          {
            model_name = "normal";
            litellm_params = {
              model = cfg.normalModel;
              api_base = cfg.goAnthropicBase;
              api_key = "os.environ/OPENCODE_KEY_1";
            };
          }

          {
            model_name = "normal-key-2";
            litellm_params = {
              model = cfg.normalModel;
              api_base = cfg.goAnthropicBase;
              api_key = "os.environ/OPENCODE_KEY_2";
            };
          }

          {
            model_name = "normal-key-3";
            litellm_params = {
              model = cfg.normalModel;
              api_base = cfg.goAnthropicBase;
              api_key = "os.environ/OPENCODE_KEY_3";
            };
          }

          {
            model_name = "normal-key-4";
            litellm_params = {
              model = cfg.normalModel;
              api_base = cfg.goAnthropicBase;
              api_key = "os.environ/OPENCODE_KEY_4";
            };
          }
        ];

        router_settings = {
          num_retries = 0;
          timeout = 120;
          allowed_fails = 0;
          cooldown_time = cfg.cooldownTime;

          fallbacks = [
            {
              # flash: Zen free key 1 -> 2 -> 3 -> 4
              #        -> Go paid key 1 -> 2 -> 3 -> 4
              "flash" = [
                "flash-free-key-2"
                "flash-free-key-3"
                "flash-free-key-4"
                "flash-paid-key-1"
                "flash-paid-key-2"
                "flash-paid-key-3"
                "flash-paid-key-4"
              ];
            }

            {
              # normal: Go key 1 -> 2 -> 3 -> 4
              "normal" = [
                "normal-key-2"
                "normal-key-3"
                "normal-key-4"
              ];
            }
          ];

          max_fallbacks = 7;

          retry_policy = {
            RateLimitErrorRetries = 0;
            TimeoutErrorRetries = 0;
            InternalServerErrorRetries = 0;
            AuthenticationErrorRetries = 0;
          };
        };

        general_settings = {
          master_key = "os.environ/LITELLM_MASTER_KEY";
        };

        litellm_settings = {
          drop_params = true;
        };
      };
      mode = "0444";
    };

    systemd.services.litellm = {
      description = "LiteLLM OpenAI-compatible LLM router";

      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        Type = "simple";
        User = "root";
        Group = "root";
        ExecStart = "${pkgs.litellm}/bin/litellm --config /etc/litellm/config.yaml --port ${toString cfg.port} --host ${cfg.host}";
        Restart = "always";
        RestartSec = 5;
        EnvironmentFile = config.sops.templates."litellm.env".path;
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "full";
        ProtectHome = true;
      };
    };
  };
}
