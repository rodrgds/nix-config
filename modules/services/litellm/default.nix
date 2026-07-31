# LiteLLM OpenAI-compatible LLM router/load balancer
# Routes requests across multiple API keys with failover.
# Model catalog lives in modules/shared/litellm.nix and is shared with the
# opencode app module so both sides always agree on the public model list.
# Upstream bases are configured via options (zen = free, go = paid).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.vps.litellm;
  yaml = pkgs.formats.yaml { };
  catalog = import ../../shared/litellm.nix;

  apiBase =
    name:
    {
      zen = cfg.zenApiBase;
      go = cfg.goApiBase;
      goAnthropic = cfg.goAnthropicBase;
    }
    .${name};

  # Expand a catalog model into its concrete variants:
  #   - first tier, first key -> plain alias (e.g. "flash")
  #   - single tier, other keys -> "<alias>-key-<n>"
  #   - multi tier, other variants -> "<alias>-<tier>-key-<n>"
  mkVariants =
    model:
    let
      tierCount = builtins.length model.tiers;
    in
    lib.concatLists (
      lib.imap1 (
        ti: tier:
        lib.genList (
          ki:
          let
            keyNum = ki + 1;
            isPrimary = ti == 1 && keyNum == 1;
            name =
              if isPrimary then
                model.alias
              else if tierCount == 1 then
                "${model.alias}-key-${toString keyNum}"
              else
                "${model.alias}-${tier.name}-key-${toString keyNum}";
          in
          {
            inherit name;
            inherit (tier) model;
            api_base = apiBase tier.api;
            api_key = "os.environ/OPENCODE_KEY_${toString keyNum}";
          }
        ) catalog.keyCount
      ) model.tiers
    );

  variants = lib.concatMap mkVariants catalog.models;

  # Chain fallbacks per model: every variant falls back to the later variants
  # of the same model only, never crossing into another model.
  mkFallbacks =
    variants:
    let
      total = builtins.length variants;
    in
    lib.flatten (
      lib.imap1 (
        i: v:
        lib.optional (i < total) {
          ${v.name} = map (x: x.name) (lib.drop i variants);
        }
      ) variants
    );

  fallbacks = lib.concatMap (model: mkFallbacks (mkVariants model)) catalog.models;

  modelList = map (v: {
    model_name = v.name;
    litellm_params = {
      inherit (v) model api_base api_key;
    };
  }) variants;
in
{
  options.vps.litellm = {
    enable = lib.mkEnableOption "Enable LiteLLM";

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
        inherit modelList;

        router_settings = {
          num_retries = 0;
          timeout = 120;
          allowed_fails = 0;
          cooldown_time = cfg.cooldownTime;

          inherit fallbacks;

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
