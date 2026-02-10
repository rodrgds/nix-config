# Uni Easy Postgres Database
# Separate postgres instance for Uni Easy project
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.vps.unieasy;

  postgresPort = 5432; # Internal container port
  exposedPort = 5435; # External port - not a secret, hardcoded
in
{
  options.vps.unieasy = {
    enable = lib.mkEnableOption "Uni Easy Postgres database";
  };

  config = lib.mkIf cfg.enable {
    # Create persistent directories
    systemd.tmpfiles.rules = [
      "d /var/lib/unieasy 0750 root root -"
      "d /var/lib/unieasy/postgres 0750 999 999 -" # postgres user
      "d /var/backup/unieasy 0750 root root -" # backup directory
    ];

    # Postgres 16 with pgvector for Uni Easy
    virtualisation.oci-containers.containers.unieasy-postgres = {
      image = "docker.io/pgvector/pgvector:pg16";

      environment = {
        POSTGRES_USER = config.sops.placeholder.unieasy_postgres_user;
        POSTGRES_DB = config.sops.placeholder.unieasy_postgres_db;
        POSTGRES_PASSWORD_FILE = "/run/secrets/postgres_password";
      };

      volumes = [
        "/var/lib/unieasy/postgres:/var/lib/postgresql/data"
      ];

      ports = [
        "127.0.0.1:${toString exposedPort}:5432"
      ];

      extraOptions = [
        "--network=podman"
      ];
    };

    # Secrets
    sops.templates = {
      "unieasy-postgres-password" = {
        content = config.sops.placeholder.unieasy_postgres_password;
      };
    };

    # Load secrets
    systemd.services.podman-unieasy-postgres.serviceConfig = {
      LoadCredential = [
        "postgres_password:${config.sops.templates.unieasy-postgres-password.path}"
      ];
    };

    # Database backup service
    systemd.services.unieasy-postgres-backup = {
      description = "Backup Uni Easy Postgres database";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "unieasy-backup" ''
          set -e
          TIMESTAMP=$(${pkgs.coreutils}/bin/date +%Y%m%d_%H%M%S)
          BACKUP_DIR="/var/backup/unieasy"
          ${pkgs.coreutils}/bin/mkdir -p "$BACKUP_DIR"

          # Dump to temporary file, then compress
          ${pkgs.podman}/bin/podman exec unieasy-postgres pg_dump \
            -U "$UNIEASY_DB_USER" \
            -d "$UNIEASY_DB_NAME" \
            > "$BACKUP_DIR/unieasy_$TIMESTAMP.sql"

          ${pkgs.gzip}/bin/gzip "$BACKUP_DIR/unieasy_$TIMESTAMP.sql"

          # Keep only last 7 days of backups
          ${pkgs.findutils}/bin/find "$BACKUP_DIR" -name "unieasy_*.sql.gz" -mtime +7 -delete

          ${pkgs.coreutils}/bin/echo "Backup completed: $BACKUP_DIR/unieasy_$TIMESTAMP.sql.gz"
        '';
        Environment = [
          "UNIEASY_DB_USER=${config.sops.placeholder.unieasy_postgres_user}"
          "UNIEASY_DB_NAME=${config.sops.placeholder.unieasy_postgres_db}"
        ];
      };
    };

    # Daily backup timer
    systemd.timers.unieasy-postgres-backup = {
      description = "Daily Uni Easy database backup";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
      };
    };

    # Note: No Caddy config needed - this is a database only, not a web service
    # Accessible on localhost:5435 (or configured port)
  };
}
