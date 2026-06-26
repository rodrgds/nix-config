# Vaultwarden password manager
# Unofficial Bitwarden server implementation
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.vps.vaultwarden;

  vaultwardenPort = 8082;
in
{
  options.vps.vaultwarden = {
    enable = lib.mkEnableOption "Enable Vaultwarden";

    domain = lib.mkOption {
      type = lib.types.str;
      default = "vault.rgo.pt";
      description = "Domain for Vaultwarden";
    };

    signupsAllowed = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Allow new signups";
    };
  };

  config = lib.mkIf cfg.enable {
    # Create persistent directories
    systemd.tmpfiles.rules = [
      "d /var/lib/vaultwarden 0750 root root -"
      "d /var/lib/vaultwarden/data 0750 1000 1000 -"
      "d /var/backup/vaultwarden 0750 root root -"
    ];

    # Vaultwarden server
    virtualisation.oci-containers.containers.vaultwarden = {
      image = "vaultwarden/server:latest";

      environment = {
        DOMAIN = "https://${cfg.domain}";
        DATABASE_URL = "data/db.sqlite3";
        SIGNUPS_ALLOWED = if cfg.signupsAllowed then "true" else "false";
        ADMIN_TOKEN_FILE = "/run/secrets/admin_token";
        IP_HEADER = "X-Forwarded-For";
        PUSH_ENABLED = "false";
      };

      volumes = [
        "/var/lib/vaultwarden/data:/data"
      ];

      ports = [
        "127.0.0.1:${toString vaultwardenPort}:80"
      ];

      extraOptions = [
        "--network=podman"
        "--health-cmd=curl -f http://127.0.0.1:80"
        "--health-interval=2s"
        "--health-timeout=10s"
        "--health-retries=15"
        "--mount=type=bind,source=/run/credentials/podman-vaultwarden.service/admin_token,target=/run/secrets/admin_token,ro"
      ];
    };

    # Secrets
    sops.templates = {
      "vaultwarden-admin-token" = {
        content = config.sops.placeholder.vaultwarden_admin_token;
      };
    };

    # Load secrets
    systemd.services.podman-vaultwarden.serviceConfig = {
      LoadCredential = [
        "admin_token:${config.sops.templates.vaultwarden-admin-token.path}"
      ];
    };

    # Backup service for SQLite database
    systemd.services.vaultwarden-backup = {
      description = "Backup Vaultwarden database";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "vaultwarden-backup" ''
          set -e
          TIMESTAMP=$(${pkgs.coreutils}/bin/date +%Y%m%d_%H%M%S)
          BACKUP_DIR="/var/backup/vaultwarden"
          ${pkgs.coreutils}/bin/mkdir -p "$BACKUP_DIR"

          # Backup SQLite database
          ${pkgs.sqlite}/bin/sqlite3 /var/lib/vaultwarden/data/db.sqlite3 ".backup '$BACKUP_DIR/vaultwarden_$TIMESTAMP.db'"

          # Compress
          ${pkgs.gzip}/bin/gzip -f "$BACKUP_DIR/vaultwarden_$TIMESTAMP.db"

          # Keep only last 7 days
          ${pkgs.findutils}/bin/find "$BACKUP_DIR" -name "vaultwarden_*.db.gz" -mtime +7 -delete

          ${pkgs.coreutils}/bin/echo "Backup completed: $BACKUP_DIR/vaultwarden_$TIMESTAMP.db.gz"
        '';
      };
    };

    systemd.timers.vaultwarden-backup = {
      description = "Daily Vaultwarden backup";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
      };
    };

    # Caddy
    vps.caddy.internalPorts.vaultwarden = vaultwardenPort;
  };
}
