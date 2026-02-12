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
    # Create persistent directories
    systemd.tmpfiles.rules = [
      "d /var/lib/ghost 0750 root root -"
      "d /var/lib/ghost/content 0750 1000 1000 -"
      "d /var/lib/ghost/mysql 0750 999 999 -"
      "d /var/backup/ghost 0750 root root -"
    ];

    # MySQL database for Ghost
    virtualisation.oci-containers.containers.ghost-mysql = {
      image = "docker.io/mysql:8.0";

      environment = {
        MYSQL_USER = config.sops.placeholder.ghost_db_user;
        MYSQL_PASSWORD_FILE = "/run/secrets/mysql_password";
        MYSQL_ROOT_PASSWORD_FILE = "/run/secrets/mysql_root_password";
        MYSQL_DATABASE = config.sops.placeholder.ghost_db_name;
      };

      volumes = [
        "/var/lib/ghost/mysql:/var/lib/mysql"
      ];

      extraOptions = [
        "--network=podman"
        "--health-cmd=mysqladmin ping -h 127.0.0.1"
        "--health-interval=5s"
        "--health-timeout=20s"
        "--health-retries=10"
        "--mount=type=bind,source=${config.sops.templates.ghost-mysql-password.path},target=/run/secrets/mysql_password,ro"
        "--mount=type=bind,source=${config.sops.templates.ghost-mysql-root-password.path},target=/run/secrets/mysql_root_password,ro"
      ];
    };

    # Ghost application
    virtualisation.oci-containers.containers.ghost = {
      image = "docker.io/ghost:5";

      environment = {
        url = "https://${cfg.domain}";
        database__client = "mysql";
        database__connection__host = "ghost-mysql";
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

      dependsOn = [ "ghost-mysql" ];

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
      "ghost-mysql-password" = {
        content = config.sops.placeholder.ghost_db_password;
        mode = "0444"; # World-readable for container access
      };
      "ghost-mysql-root-password" = {
        content = config.sops.placeholder.ghost_db_root_password;
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

    # MySQL backup service
    systemd.services.ghost-mysql-backup = {
      description = "Backup Ghost MySQL database";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "ghost-backup" ''
          set -e
          TIMESTAMP=$(${pkgs.coreutils}/bin/date +%Y%m%d_%H%M%S)
          BACKUP_DIR="/var/backup/ghost"
          ${pkgs.coreutils}/bin/mkdir -p "$BACKUP_DIR"

          # Dump to temporary file, then compress
          ${pkgs.podman}/bin/podman exec ghost-mysql mysqldump \
            -u root \
            -p"$(${pkgs.coreutils}/bin/cat /run/secrets/mysql_root_password)" \
            "$GHOST_DB_NAME" \
            > "$BACKUP_DIR/ghost_$TIMESTAMP.sql"

          ${pkgs.gzip}/bin/gzip "$BACKUP_DIR/ghost_$TIMESTAMP.sql"

          ${pkgs.findutils}/bin/find "$BACKUP_DIR" -name "ghost_*.sql.gz" -mtime +7 -delete

          ${pkgs.coreutils}/bin/echo "Backup completed: $BACKUP_DIR/ghost_$TIMESTAMP.sql.gz"
        '';
        Environment = [
          "GHOST_DB_NAME=${config.sops.placeholder.ghost_db_name}"
        ];
      };
    };

    systemd.timers.ghost-mysql-backup = {
      description = "Daily Ghost database backup";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
      };
    };

    # Caddy
    vps.caddy.internalPorts.ghost = ghostPort;
  };
}
