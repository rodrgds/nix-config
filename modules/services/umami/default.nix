# Umami analytics
# Privacy-focused web analytics
#
# Uses shared PostgreSQL instance (vps.postgres) to save memory
# Previously had its own postgres container (~28 MB), now shares with ghost
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.vps.umami;

  umamiPort = 3000;
in
{
  options.vps.umami = {
    enable = lib.mkEnableOption "Umami analytics";

    domain = lib.mkOption {
      type = lib.types.str;
      default = "analytics.rgo.pt";
      description = "Domain for Umami";
    };
  };

  config = lib.mkIf cfg.enable {
    # Create persistent directories
    systemd.tmpfiles.rules = [
      "d /var/lib/umami 0750 root root -"
    ];

    # Umami application (uses shared PostgreSQL instance)
    virtualisation.oci-containers.containers.umami = {
      image = "ghcr.io/umami-software/umami:postgresql-latest";

      environmentFiles = [
        config.sops.templates.umami-env.path
      ];

      environment = {
        DATABASE_TYPE = "postgres";
      };

      ports = [
        "127.0.0.1:${toString umamiPort}:3000"
      ];

      dependsOn = [ "shared-postgres" ];

      extraOptions = [
        "--network=podman"
        "--health-cmd=curl -f http://127.0.0.1:3000/api/heartbeat"
        "--health-interval=5s"
        "--health-timeout=20s"
        "--health-retries=10"
      ];
    };

    # Secrets
    sops.templates = {
      "umami-env" = {
        content = ''
          DATABASE_URL=postgres://${config.sops.placeholder.umami_db_user}:${config.sops.placeholder.umami_db_password}@shared-postgres:5432/${config.sops.placeholder.umami_db_name}
          APP_SECRET=${config.sops.placeholder.umami_app_secret}
        '';
        mode = "0444";
      };
    };

    # Caddy
    vps.caddy.internalPorts.umami = umamiPort;
  };
}
