# Umami analytics
# Privacy-focused web analytics
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.vps.umami;
  databaseRoles = import ../_postgres-roles.nix {
    inherit lib pkgs;
    service = "umami";
    applicationRoleFile = "/run/secrets/db_user";
    applicationDatabaseFile = "/run/secrets/db_name";
    applicationPasswordFile = "/run/secrets/postgres_password";
    adminPasswordFile = "/run/secrets/admin_password";
    extensions = [ "pgcrypto" ];
  };

  umamiPort = 3000;
  postgresPort = 5433; # Different from n8n
in
{
  options.vps.umami = {
    enable = lib.mkEnableOption "Enable Umami";

    domain = lib.mkOption {
      type = lib.types.str;
      default = "cool.rgo.pt";
      description = "Domain for Umami";
    };
  };

  config = lib.mkIf cfg.enable {
    sops.secrets = lib.genAttrs [
      "umami_postgres_admin_password"
      "umami_db_password"
      "umami_db_user"
      "umami_db_name"
      "umami_app_secret"
    ] (_: { });

    # Create persistent directories
    systemd.tmpfiles.rules = [
      "d /var/lib/umami 0750 root root -"
      "d /var/lib/umami/postgres 0700 70 70 -"
      "d /var/backup/umami 0750 root root -"
    ];

    # Umami Postgres database
    virtualisation.oci-containers.containers.umami-postgres = {
      image = "docker.io/postgres:16-alpine";

      environment = {
        POSTGRES_USER = "umami_cluster_admin";
        POSTGRES_DB_FILE = "/run/secrets/db_name";
        POSTGRES_PASSWORD_FILE = "/run/secrets/admin_password";
      };

      volumes = [
        "/var/lib/umami/postgres:/var/lib/postgresql/data"
      ];

      ports = [
        "127.0.0.1:${toString postgresPort}:5432"
      ];

      # Health check
      extraOptions = [
        "--network=podman"
        "--mount=type=bind,source=${config.sops.templates.umami-postgres-admin-password.path},target=/run/secrets/admin_password,ro"
        "--mount=type=bind,source=${config.sops.templates.umami-postgres-password.path},target=/run/secrets/postgres_password,ro"
        "--mount=type=bind,source=${config.sops.templates.umami-db-user.path},target=/run/secrets/db_user,ro"
        "--mount=type=bind,source=${config.sops.templates.umami-db-name.path},target=/run/secrets/db_name,ro"
        "--health-cmd=sh -ec 'pg_isready -h 127.0.0.1 -U umami_cluster_admin -d \"$(cat /run/secrets/db_name)\"'"
        "--health-interval=5s"
        "--health-timeout=20s"
        "--health-retries=10"
      ];
    };

    # Umami application
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

      dependsOn = [ "umami-postgres" ];

      extraOptions = [
        "--network=podman"
        "--health-cmd=curl -f http://127.0.0.1:3000/api/heartbeat"
        "--health-interval=5s"
        "--health-timeout=20s"
        "--health-retries=10"
      ];
    };

    systemd.services.umami-postgres-roles = {
      description = "Separate umami PostgreSQL cluster administration";
      requires = [ "podman-umami-postgres.service" ];
      after = [ "podman-umami-postgres.service" ];
      before = [ "podman-umami.service" ];
      requiredBy = [ "podman-umami.service" ];
      restartTriggers = [ databaseRoles ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = databaseRoles;
      };
    };
    systemd.services.podman-umami.restartTriggers = [ databaseRoles ];

    # Secrets
    sops.templates = {
      "umami-postgres-admin-password" = {
        content = config.sops.placeholder.umami_postgres_admin_password;
        mode = "0400";
        restartUnits = [
          "podman-umami-postgres.service"
          "umami-postgres-roles.service"
          "podman-umami.service"
        ];
      };
      "umami-postgres-password" = {
        content = config.sops.placeholder.umami_db_password;
        # Podman and the PostgreSQL entrypoint read this as root before dropping privileges.
        mode = "0400";
        restartUnits = [
          "podman-umami-postgres.service"
          "umami-postgres-roles.service"
          "podman-umami.service"
        ];
      };
      "umami-db-user" = {
        content = config.sops.placeholder.umami_db_user;
        mode = "0400";
        restartUnits = [
          "podman-umami-postgres.service"
          "umami-postgres-roles.service"
          "podman-umami.service"
        ];
      };
      "umami-db-name" = {
        content = config.sops.placeholder.umami_db_name;
        mode = "0400";
        restartUnits = [
          "podman-umami-postgres.service"
          "umami-postgres-roles.service"
          "podman-umami.service"
        ];
      };
      "umami-env" = {
        content = ''
          DATABASE_URL=postgres://${config.sops.placeholder.umami_db_user}:${config.sops.placeholder.umami_db_password}@umami-postgres:5432/${config.sops.placeholder.umami_db_name}
          APP_SECRET=${config.sops.placeholder.umami_app_secret}
        '';
        mode = "0400";
      };
    };

    # Backup service
    systemd.services.umami-postgres-backup = {
      description = "Backup Umami Postgres database";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "umami-backup" ''
          set -euo pipefail
          TIMESTAMP=$(${pkgs.coreutils}/bin/date +%Y%m%d_%H%M%S)
          BACKUP_DIR="/var/backup/umami"
          UMAMI_DB_USER=$(${pkgs.coreutils}/bin/cat ${config.sops.templates.umami-db-user.path})
          UMAMI_DB_NAME=$(${pkgs.coreutils}/bin/cat ${config.sops.templates.umami-db-name.path})
          ${pkgs.coreutils}/bin/mkdir -p "$BACKUP_DIR"

          # Dump database and pipe to gzip
          ${pkgs.podman}/bin/podman exec umami-postgres pg_dump \
            -U "$UMAMI_DB_USER" \
            -d "$UMAMI_DB_NAME" | ${pkgs.gzip}/bin/gzip > "$BACKUP_DIR/umami_$TIMESTAMP.sql.gz"

          ${pkgs.findutils}/bin/find "$BACKUP_DIR" -name "umami_*.sql.gz" -mtime +7 -delete

          ${pkgs.coreutils}/bin/echo "Backup completed: $BACKUP_DIR/umami_$TIMESTAMP.sql.gz"
        '';
      };
    };

    systemd.timers.umami-postgres-backup = {
      description = "Daily Umami database backup";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
      };
    };

    # Caddy
    vps.caddy.internalPorts.umami = umamiPort;
  };
}
