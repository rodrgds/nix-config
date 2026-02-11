# Shared PostgreSQL instance for VPS services
# Used by: umami, ghost
#
# Consolidates multiple postgres instances into one to save memory (~50 MB savings)
# Both umami and ghost use PostgreSQL 16 Alpine, so they can share one server
# Each service has its own database and user for isolation
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.vps.postgres;
  sharedPostgresPort = 5432;
in
{
  options.vps.postgres = {
    enable = lib.mkEnableOption "Enable shared PostgreSQL instance";
  };

  config = lib.mkIf cfg.enable {
    # Create persistent directory
    systemd.tmpfiles.rules = [
      "d /var/lib/shared-postgres 0700 70 70 -"
      "d /var/backup/shared-postgres 0750 root root -"
    ];

    # Shared PostgreSQL container
    virtualisation.oci-containers.containers.shared-postgres = {
      image = "docker.io/postgres:16-alpine";

      environment = {
        POSTGRES_PASSWORD_FILE = "/run/secrets/postgres_password";
      };

      volumes = [
        "/var/lib/shared-postgres:/var/lib/postgresql/data"
      ];

      ports = [
        "127.0.0.1:${toString sharedPostgresPort}:5432"
      ];

      extraOptions = [
        "--network=podman"
        "--mount=type=bind,source=${config.sops.templates.shared-postgres-password.path},target=/run/secrets/postgres_password,ro"
        "--health-cmd=pg_isready -U postgres"
        "--health-interval=5s"
        "--health-timeout=20s"
        "--health-retries=10"
      ];
    };

    # Secrets
    sops.templates."shared-postgres-password" = {
      content = config.sops.placeholder.shared_postgres_password;
      mode = "0444";
    };

    # Setup script to create databases and users
    systemd.services.shared-postgres-setup = {
      description = "Setup shared PostgreSQL databases and users";
      wantedBy = [ "multi-user.target" ];
      after = [ "podman-shared-postgres.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "shared-postgres-setup" ''
          set -e
          # Wait for postgres to be ready (with retries)
          for i in $(seq 1 30); do
            if ${pkgs.podman}/bin/podman exec shared-postgres pg_isready -U postgres -t 2 >/dev/null 2>&1; then
              break
            fi
            echo "Waiting for PostgreSQL to be ready... ($i/30)"
            ${pkgs.coreutils}/bin/sleep 2
          done

          # Create databases and users for each service
          ${pkgs.podman}/bin/podman exec shared-postgres psql -U postgres -v ON_ERROR_STOP=1 <<-EOSQL
            -- Ghost database
            CREATE USER ${config.sops.placeholder.ghost_db_user} WITH PASSWORD '${config.sops.placeholder.ghost_db_password}';
            CREATE DATABASE ${config.sops.placeholder.ghost_db_name} OWNER ${config.sops.placeholder.ghost_db_user};

            -- Umami database
            CREATE USER ${config.sops.placeholder.umami_db_user} WITH PASSWORD '${config.sops.placeholder.umami_db_password}';
            CREATE DATABASE ${config.sops.placeholder.umami_db_name} OWNER ${config.sops.placeholder.umami_db_user};
          EOSQL

          echo "✅ Shared PostgreSQL setup complete"
        '';
      };
    };

    # Backup service for all databases
    systemd.services.shared-postgres-backup = {
      description = "Backup all shared PostgreSQL databases";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "shared-postgres-backup" ''
          set -e
          TIMESTAMP=$(${pkgs.coreutils}/bin/date +%Y%m%d_%H%M%S)
          BACKUP_DIR="/var/backup/shared-postgres"
          ${pkgs.coreutils}/bin/mkdir -p "$BACKUP_DIR"

          # Backup all databases
          ${pkgs.podman}/bin/podman exec shared-postgres pg_dumpall -U postgres | ${pkgs.gzip}/bin/gzip > "$BACKUP_DIR/shared-postgres_$TIMESTAMP.sql.gz"

          ${pkgs.findutils}/bin/find "$BACKUP_DIR" -name "shared-postgres_*.sql.gz" -mtime +7 -delete

          ${pkgs.coreutils}/bin/echo "Backup completed: $BACKUP_DIR/shared-postgres_$TIMESTAMP.sql.gz"
        '';
      };
    };

    systemd.timers.shared-postgres-backup = {
      description = "Daily shared PostgreSQL backup";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
      };
    };
  };
}
