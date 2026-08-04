# Directus Headless CMS (SQLite)
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.vps.directus;
  directusPort = 8055;
  backupDirectory = "/var/backup/directus";

  backupDirectus = pkgs.writeShellScript "backup-directus" ''
    set -euo pipefail

    backup_dir=${backupDirectory}
    database=/var/lib/directus/database/data.db
    timestamp="$(${pkgs.coreutils}/bin/date --utc +%Y%m%dT%H%M%SZ)"
    archive="$backup_dir/directus-$timestamp.tar.gz"
    temporary="$(${pkgs.coreutils}/bin/mktemp -d "$backup_dir/.backup-XXXXXXXX")"
    trap '${pkgs.coreutils}/bin/rm -rf -- "$temporary"' EXIT

    ${pkgs.sqlite}/bin/sqlite3 -cmd ".timeout 30000" "$database" ".backup '$temporary/database.sqlite'"
    ${pkgs.gnutar}/bin/tar \
      --create \
      --gzip \
      --file "$archive" \
      --directory "$temporary" database.sqlite \
      --directory /var/lib/directus uploads
    ${pkgs.coreutils}/bin/sha256sum "$archive" > "$archive.sha256"

    mapfile -t stale_backups < <(
      ${pkgs.findutils}/bin/find "$backup_dir" -maxdepth 1 -type f -name 'directus-*.tar.gz' -printf '%T@ %p\n' \
        | ${pkgs.coreutils}/bin/sort --numeric-sort --reverse \
        | ${pkgs.coreutils}/bin/tail --lines=+8 \
        | ${pkgs.gawk}/bin/awk '{ sub(/^[^ ]+ /, ""); print }'
    )
    for stale_backup in "''${stale_backups[@]}"; do
      case "$stale_backup" in
        "$backup_dir"/directus-*.tar.gz)
          ${pkgs.coreutils}/bin/rm --force -- "$stale_backup" "$stale_backup.sha256"
          ;;
        *)
          echo "Refusing to remove unexpected backup path: $stale_backup" >&2
          exit 1
          ;;
      esac
    done
  '';

  checkDirectusBackup = pkgs.writeShellScript "check-directus-backup" ''
    set -euo pipefail

    backup_dir=${backupDirectory}
    latest="$(${pkgs.findutils}/bin/find "$backup_dir" -maxdepth 1 -type f -name 'directus-*.tar.gz' -printf '%T@ %p\n' \
      | ${pkgs.coreutils}/bin/sort --numeric-sort --reverse \
      | ${pkgs.coreutils}/bin/head --lines=1 \
      | ${pkgs.gawk}/bin/awk '{ sub(/^[^ ]+ /, ""); print }')"
    if [ -z "$latest" ]; then
      echo "No Directus backup is available to verify" >&2
      exit 1
    fi

    ${pkgs.coreutils}/bin/sha256sum --check "$latest.sha256"
    ${pkgs.gnutar}/bin/tar --extract --gzip --file "$latest" --directory "$RUNTIME_DIRECTORY" database.sqlite
    integrity="$(${pkgs.sqlite}/bin/sqlite3 "$RUNTIME_DIRECTORY/database.sqlite" 'PRAGMA integrity_check;')"
    if [ "$integrity" != ok ]; then
      echo "Directus backup integrity check failed: $integrity" >&2
      exit 1
    fi
  '';
in
{
  options.vps.directus = {
    enable = lib.mkEnableOption "Enable Directus";
    domain = lib.mkOption {
      type = lib.types.str;
      default = "directus.rgo.pt";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d /var/lib/directus 0750 root root -"
      "d /var/lib/directus/database 0750 1000 1000 -"
      "d /var/lib/directus/uploads 0750 1000 1000 -"
      "d /var/lib/directus/extensions 0750 1000 1000 -"
      "d ${backupDirectory} 0700 root root -"
    ];

    virtualisation.oci-containers.containers.directus = {
      # Keep upgrades explicit so a container restart cannot silently migrate the database.
      image = "directus/directus:11.15.3";

      environment = {
        DB_CLIENT = "sqlite3";
        DB_FILENAME = "/directus/database/data.db";
        PUBLIC_URL = "https://${cfg.domain}";
        CORS_ENABLED = "false";
      };

      environmentFiles = [
        config.sops.templates.directus-env.path
      ];

      volumes = [
        "/var/lib/directus/database:/directus/database"
        "/var/lib/directus/uploads:/directus/uploads"
        "/var/lib/directus/extensions:/directus/extensions"
      ];

      ports = [
        "127.0.0.1:${toString directusPort}:8055"
      ];

      extraOptions = [
        "--network=podman"
      ];
    };

    sops.templates."directus-env" = {
      content = ''
        KEY=${config.sops.placeholder.directus_key}
        SECRET=${config.sops.placeholder.directus_secret}
        ADMIN_EMAIL=${config.sops.placeholder.directus_admin_email}
        ADMIN_PASSWORD=${config.sops.placeholder.directus_admin_password}
      '';
      mode = "0400";
    };

    systemd.services.directus-backup = {
      description = "Create a consistent, bounded Directus backup";
      after = [ "podman-directus.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = backupDirectus;
        Nice = 10;
        IOSchedulingClass = "idle";
        PrivateTmp = true;
        NoNewPrivileges = true;
        ReadWritePaths = [ backupDirectory ];
      };
    };

    systemd.timers.directus-backup = {
      description = "Daily Directus backup schedule";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*-*-* 03:20:00";
        Persistent = true;
        RandomizedDelaySec = "20min";
      };
    };

    systemd.services.directus-backup-check = {
      description = "Verify the newest Directus backup can be read";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = checkDirectusBackup;
        RuntimeDirectory = "directus-backup-check";
        PrivateTmp = true;
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ReadOnlyPaths = [ backupDirectory ];
      };
    };

    systemd.timers.directus-backup-check = {
      description = "Weekly Directus restore check";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "Sun *-*-* 05:00:00";
        Persistent = true;
        RandomizedDelaySec = "30min";
      };
    };

    vps.caddy.internalPorts.directus = directusPort;
  };
}
