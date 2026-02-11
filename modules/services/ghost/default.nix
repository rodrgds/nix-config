# Ghost blog
# Modern publishing platform
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.vps.ghost;

  ghostPort = 2368;
in
{
  options.vps.ghost = {
    enable = lib.mkEnableOption "Ghost blog";

    domain = lib.mkOption {
      type = lib.types.str;
      default = "cs.rgo.pt";
      description = "Domain for Ghost";
    };
  };

  config = lib.mkIf cfg.enable {
    # Migrated from MySQL to PostgreSQL for ~400 MB memory savings
    # MySQL 8.0: ~455 MB, PostgreSQL 16 Alpine: ~30-50 MB
    # Now uses shared PostgreSQL instance with umami

    # Create persistent directories
    systemd.tmpfiles.rules = [
      "d /var/lib/ghost 0750 root root -"
      "d /var/lib/ghost/content 0750 1000 1000 -"
    ];

    # Ghost application (uses shared PostgreSQL instance)
    virtualisation.oci-containers.containers.ghost = {
      image = "docker.io/ghost:5";

      environment = {
        url = "https://${cfg.domain}";
        database__client = "pg";
        database__connection__host = "shared-postgres";
      };

      environmentFiles = [
        config.sops.templates.ghost-env.path
      ];

      volumes = [
        "/var/lib/ghost/content:/var/lib/ghost/content"
      ];

      ports = [
        "127.0.0.1:${toString ghostPort}:2368"
      ];

      dependsOn = [ "shared-postgres" ];

      extraOptions = [
        "--network=podman"
        "--health-cmd='echo ok'"
        "--health-interval=5s"
        "--health-timeout=20s"
        "--health-retries=10"
      ];
    };

    # Secrets
    sops.templates = {
      "ghost-env" = {
        content = ''
          database__connection__user=${config.sops.placeholder.ghost_db_user}
          database__connection__password=${config.sops.placeholder.ghost_db_password}
          database__connection__database=${config.sops.placeholder.ghost_db_name}
          mail__transport=SMTP
          mail__options__service=Mailgun
          mail__options__host=smtp.eu.mailgun.org
          mail__options__port=465
          mail__options__secure=true
          mail__options__auth__user=${config.sops.placeholder.ghost_mailgun_user}
          mail__options__auth__pass=${config.sops.placeholder.ghost_mailgun_password}
        '';
        mode = "0444"; # World-readable for container access
      };
      "ghost-mailgun-user" = {
        content = config.sops.placeholder.ghost_mailgun_user;
        mode = "0444"; # World-readable for container access
      };
      "ghost-mailgun-password" = {
        content = config.sops.placeholder.ghost_mailgun_password;
        mode = "0444"; # World-readable for container access
      };
    };

    # Caddy
    vps.caddy.internalPorts.ghost = ghostPort;
  };
}
