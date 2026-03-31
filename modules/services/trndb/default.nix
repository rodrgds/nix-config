# TRNDb Directus Headless CMS (PostgreSQL)
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.vps.trndb;
  trndbPort = 8056;
  postgresPort = 5435;
in
{
  options.vps.trndb = {
    enable = lib.mkEnableOption "TRNDb Directus Headless CMS";
    domain = lib.mkOption {
      type = lib.types.str;
      default = "trndb.rgo.pt";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d /var/lib/trndb 0750 root root -"
      "d /var/lib/trndb/postgres 0700 70 70 -"
      "d /var/lib/trndb/uploads 0750 1000 1000 -"
      "d /var/lib/trndb/extensions 0750 1000 1000 -"
    ];

    virtualisation.oci-containers.containers.trndb-postgres = {
      image = "docker.io/postgres:16-alpine";

      environment = {
        POSTGRES_USER_FILE = "/run/secrets/db_user";
        POSTGRES_DB_FILE = "/run/secrets/db_name";
        POSTGRES_PASSWORD_FILE = "/run/secrets/postgres_password";
      };

      volumes = [
        "/var/lib/trndb/postgres:/var/lib/postgresql/data"
      ];

      ports = [
        "127.0.0.1:${toString postgresPort}:5432"
      ];

      extraOptions = [
        "--network=podman"
        "--mount=type=bind,source=${config.sops.templates.trndb-postgres-password.path},target=/run/secrets/postgres_password,ro"
        "--mount=type=bind,source=${config.sops.templates.trndb-db-user.path},target=/run/secrets/db_user,ro"
        "--mount=type=bind,source=${config.sops.templates.trndb-db-name.path},target=/run/secrets/db_name,ro"
        "--health-cmd=pg_isready -U trndb -d trndb"
        "--health-interval=5s"
        "--health-timeout=20s"
        "--health-retries=10"
      ];
    };

    virtualisation.oci-containers.containers.trndb = {
      image = "directus/directus:latest";

      environment = {
        DB_CLIENT = "postgres";
        DB_HOST = "trndb-postgres";
        DB_PORT = "5432";
        PUBLIC_URL = "https://${cfg.domain}";
        CORS_ENABLED = "true";
      };

      environmentFiles = [
        config.sops.templates.trndb-env.path
      ];

      volumes = [
        "/var/lib/trndb/uploads:/directus/uploads"
        "/var/lib/trndb/extensions:/directus/extensions"
      ];

      ports = [
        "127.0.0.1:${toString trndbPort}:8055"
      ];

      dependsOn = [ "trndb-postgres" ];

      extraOptions = [
        "--network=podman"
        "--health-cmd=wget --no-verbose --tries=1 --spider http://127.0.0.1:8055/server/health || wget --no-verbose --tries=1 --spider http://127.0.0.1:8055/"
        "--health-interval=30s"
        "--health-timeout=10s"
        "--health-retries=3"
        "--health-start-period=60s"
      ];
    };

    sops.templates = {
      "trndb-postgres-password" = {
        content = config.sops.placeholder.trndb_db_password;
        mode = "0444";
      };
      "trndb-db-user" = {
        content = config.sops.placeholder.trndb_db_user;
        mode = "0444";
      };
      "trndb-db-name" = {
        content = config.sops.placeholder.trndb_db_name;
        mode = "0444";
      };
      "trndb-env" = {
        content = ''
          KEY=${config.sops.placeholder.trndb_key}
          SECRET=${config.sops.placeholder.trndb_secret}
          ADMIN_EMAIL=${config.sops.placeholder.trndb_admin_email}
          ADMIN_PASSWORD=${config.sops.placeholder.trndb_admin_password}
          DB_DATABASE=${config.sops.placeholder.trndb_db_name}
          DB_USER=${config.sops.placeholder.trndb_db_user}
          DB_PASSWORD=${config.sops.placeholder.trndb_db_password}
        '';
        mode = "0444";
      };
    };

    vps.caddy.internalPorts.trndb = trndbPort;
  };
}
