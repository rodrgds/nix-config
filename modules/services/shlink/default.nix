# Shlink URL shortener
# Self-hosted URL shortener with web client
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.vps.shlink;

  shlinkApiPort = 8081;
  shlinkWebPort = 8080;
in
{
  options.vps.shlink = {
    enable = lib.mkEnableOption "Shlink URL shortener";

    defaultDomain = lib.mkOption {
      type = lib.types.str;
      default = "url.rgo.pt";
      description = "Default domain for short URLs";
    };
  };

  config = lib.mkIf cfg.enable {
    # Create persistent directories
    systemd.tmpfiles.rules = [
      "d /var/lib/shlink 0750 root root -"
      "d /var/lib/shlink/data 0750 1000 1000 -"
    ];

    # Shlink API server
    virtualisation.oci-containers.containers.shlink = {
      image = "shlinkio/shlink:stable";

      environment = {
        DEFAULT_DOMAIN = cfg.defaultDomain;
        IS_HTTPS_ENABLED = "true";
        GEOLITE_LICENSE_KEY_FILE = "/run/secrets/geolite_license"; # Optional
        SHELL_VERBOSITY = "3"; # Enable verbose logging for debugging
      };

      volumes = [
        "/var/lib/shlink/data:/etc/shlink/data"
      ];

      ports = [
        "127.0.0.1:${toString shlinkApiPort}:8080"
      ];

      extraOptions = [
        "--network=podman"
        "--health-cmd=curl -f http://127.0.0.1:8080/rest/v3/health"
        "--health-interval=2s"
        "--health-timeout=10s"
        "--health-retries=15"
        "--mount=type=bind,source=${config.sops.templates.shlink-geolite.path},target=/run/secrets/geolite_license,ro"
      ];
    };

    # Shlink Web Client
    virtualisation.oci-containers.containers.shlink-web = {
      image = "shlinkio/shlink-web-client";

      environment = {
        SHLINK_SERVER_URL = "https://${cfg.defaultDomain}";
      };

      ports = [
        "127.0.0.1:${toString shlinkWebPort}:8080"
      ];

      extraOptions = [
        "--network=podman"
        "--health-cmd=curl -f http://127.0.0.1:8080"
        "--health-interval=2s"
        "--health-timeout=10s"
        "--health-retries=15"
      ];
    };

    # Secrets
    sops.templates = {
      "shlink-api-key" = {
        content = config.sops.placeholder.shlink_api_key;
        mode = "0444"; # World-readable for container access
      };
      "shlink-geolite" = {
        content = config.sops.placeholder.shlink_geolite_license_key or "";
        mode = "0444"; # World-readable for container access
      };
    };

    # Caddy - multiple domains
    vps.caddy.internalPorts.shlink = shlinkApiPort;
    vps.caddy.internalPorts.shlink-web = shlinkWebPort;

    # Additional Caddy config for multiple domains handled in caddy module
  };
}
