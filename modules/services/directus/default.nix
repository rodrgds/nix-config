# Directus Headless CMS (PostgreSQL)
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.vps.directus;
  directusPort = 8055;
  postgresPort = 5434;
in
{
  options.vps.directus = {
    enable = lib.mkEnableOption "Directus Headless CMS";
    domain = lib.mkOption {
      type = lib.types.str;
      default = "directus.rgo.pt";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d /var/lib/directus 0750 root root -"
      "d /var/lib/directus/postgres 0700 70 70 -"
      "d /var/lib/directus/uploads 0750 1000 1000 -"
      "d /var/lib/directus/extensions 0750 1000 1000 -"
    ];

    virtualisation.oci-containers.containers.directus-postgres = {
      image = "docker.io/postgres:16-alpine";

      environment = {
        POSTGRES_USER_FILE = "/run/secrets/db_user";
        POSTGRES_DB_FILE = "/run/secrets/db_name";
        POSTGRES_PASSWORD_FILE = "/run/secrets/postgres_password";
      };

      volumes = [
        "/var/lib/directus/postgres:/var/lib/postgresql/data"
      ];

      ports = [
        "127.0.0.1:${toString postgresPort}:5432"
      ];

      extraOptions = [
        "--network=podman"
        "--mount=type=bind,source=${config.sops.templates.directus-postgres-password.path},target=/run/secrets/postgres_password,ro"
        "--mount=type=bind,source=${config.sops.templates.directus-db-user.path},target=/run/secrets/db_user,ro"
        "--mount=type=bind,source=${config.sops.templates.directus-db-name.path},target=/run/secrets/db_name,ro"
        "--health-cmd=pg_isready -U directus -d directus"
        "--health-interval=5s"
        "--health-timeout=20s"
        "--health-retries=10"
      ];
    };

    virtualisation.oci-containers.containers.directus = {
      image = "directus/directus:latest";

      environment = {
        DB_CLIENT = "postgres";
        DB_HOST = "directus-postgres";
        DB_PORT = "5432";
        DB_DATABASE = config.sops.placeholder.directus_db_name;
        DB_USER = config.sops.placeholder.directus_db_user;
        DB_PASSWORD_FILE = "/run/secrets/db_password";
        PUBLIC_URL = "https://${cfg.domain}";
        CORS_ENABLED = "true";
      };

      environmentFiles = [
        config.sops.templates.directus-env.path
      ];

      volumes = [
        "/var/lib/directus/uploads:/directus/uploads"
        "/var/lib/directus/extensions:/directus/extensions"
      ];

      ports = [
        "127.0.0.1:${toString directusPort}:8055"
      ];

      dependsOn = [ "directus-postgres" ];

      extraOptions = [
        "--network=podman"
        "--mount=type=bind,source=${config.sops.templates.directus-db-password.path},target=/run/secrets/db_password,ro"
        "--health-cmd=wget --no-verbose --tries=1 --spider http://127.0.0.1:8055/health"
        "--health-interval=5s"
        "--health-timeout=20s"
        "--health-retries=10"
      ];
    };

    sops.templates = {
      "directus-postgres-password" = {
        content = config.sops.placeholder.directus_db_password;
        mode = "0444";
      };
      "directus-db-user" = {
        content = config.sops.placeholder.directus_db_user;
        mode = "0444";
      };
      "directus-db-name" = {
        content = config.sops.placeholder.directus_db_name;
        mode = "0444";
      };
      "directus-db-password" = {
        content = config.sops.placeholder.directus_db_password;
        mode = "0444";
      };
      "directus-env" = {
        content = ''
          KEY=${config.sops.placeholder.directus_key}
          SECRET=${config.sops.placeholder.directus_secret}
          ADMIN_EMAIL=${config.sops.placeholder.directus_admin_email}
          ADMIN_PASSWORD=${config.sops.placeholder.directus_admin_password}
        '';
        mode = "0444";
      };
    };

    vps.caddy.internalPorts.directus = directusPort;
  };
}
