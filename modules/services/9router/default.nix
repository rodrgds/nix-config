# 9Router AI gateway
# OpenAI-compatible proxy with dashboard, API key management, and Headroom sidecar.
{
  config,
  lib,
  ...
}:
let
  cfg = config.vps."9router";
  containerPort = 20128;
in
{
  options.vps."9router" = {
    enable = lib.mkEnableOption "9Router AI gateway";

    bindAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Host address to expose 9Router on. Use the VPS Tailscale IP.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 20128;
      description = "9Router host port";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.bindAddress != "0.0.0.0" && cfg.bindAddress != "::";
        message = "9Router should not be exposed on all interfaces. Bind it to localhost or the Tailscale IP.";
      }
    ];

    systemd.tmpfiles.rules = [
      "d /var/lib/9router 0750 root root -"
      "d /var/lib/9router/data 0750 root root -"
    ];

    sops.templates."9router.env" = {
      content = ''
        JWT_SECRET=${config.sops.placeholder.nine_router_jwt_secret}
        INITIAL_PASSWORD=${config.sops.placeholder.nine_router_initial_password}
        API_KEY_SECRET=${config.sops.placeholder.nine_router_api_key_secret}
        MACHINE_ID_SALT=${config.sops.placeholder.nine_router_machine_id_salt}
      '';
      mode = "0400";
    };

    virtualisation.oci-containers.containers = {
      "9router-headroom" = {
        image = "ghcr.io/chopratejas/headroom:latest";

        extraOptions = [
          "--network=podman"
        ];
      };

      "9router" = {
        image = "docker.io/decolua/9router:latest";

        environment = {
          DATA_DIR = "/app/data";
          PORT = toString containerPort;
          HOSTNAME = "0.0.0.0";
          NODE_ENV = "production";

          HEADROOM_URL = "http://9router-headroom:8787";

          ENABLE_REQUEST_LOGS = "false";
          OBSERVABILITY_ENABLED = "false";
          AUTH_COOKIE_SECURE = "false";
          REQUIRE_API_KEY = "true";

          BASE_URL = "http://127.0.0.1:${toString containerPort}";
        };

        environmentFiles = [
          config.sops.templates."9router.env".path
        ];

        volumes = [
          "/var/lib/9router/data:/app/data"
        ];

        ports = [
          "${cfg.bindAddress}:${toString cfg.port}:${toString containerPort}"
        ];

        dependsOn = [
          "9router-headroom"
        ];

        extraOptions = [
          "--network=podman"
        ];
      };
    };

    systemd.services.podman-9router = {
      after = [
        "network-online.target"
        "tailscaled.service"
      ];
      wants = [
        "network-online.target"
        "tailscaled.service"
      ];
    };

    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
      cfg.port
    ];
  };
}
