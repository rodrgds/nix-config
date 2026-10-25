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

  # Use the pinned image's SQLite driver, but never Directus's pooled connection.
  # SELECT 1 and HTTP ping can succeed while a failed COMMIT blocks new readers.
  sqliteHealthCommand =
    "node -e "
    + lib.escapeShellArg ''
      const { createRequire } = require('node:module');
      const { realpathSync } = require('node:fs');
      const api = createRequire(realpathSync('/directus/node_modules/@directus/api/package.json'));
      const sqlite = createRequire(api.resolve('knex/package.json'))('sqlite3');
      const deadline = setTimeout(() => process.exit(1), 3000);
      const db = new sqlite.Database(process.env.DB_FILENAME, sqlite.OPEN_READONLY, (error) => {
        if (error) process.exit(1);
        db.configure('busyTimeout', 1000);
        db.get('SELECT count(*) FROM sqlite_schema', (error) => {
          db.close((closeError) => {
            clearTimeout(deadline);
            if (error || closeError) console.error('Directus independent SQLite read failed');
            process.exit(error || closeError ? 1 : 0);
          });
        });
      });
    '';
  startupHealthCommand =
    "node -e "
    + lib.escapeShellArg ''
      fetch('http://127.0.0.1:8055/server/ping', { signal: AbortSignal.timeout(1000) })
        .then(response => process.exit(response.ok ? 0 : 1)).catch(() => process.exit(1));
    '';

  backupDirectus = pkgs.writeShellScript "backup-directus" ''
    set -euo pipefail

    backup_dir=${backupDirectory}
    database=/var/lib/directus/database/data.db
    timestamp="$(${pkgs.coreutils}/bin/date --utc +%Y%m%dT%H%M%SZ)"
    archive="$backup_dir/directus-$timestamp.tar.gz"
    temporary="$(${pkgs.coreutils}/bin/mktemp -d "$backup_dir/.backup-XXXXXXXX")"
    cleanup() {
      ${pkgs.coreutils}/bin/rm -rf -- "$temporary"
      if [ ! -f "$archive.sha256" ]; then
        ${pkgs.coreutils}/bin/rm --force -- "$archive"
      fi
    }
    trap cleanup EXIT

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
    sops.secrets = lib.genAttrs [
      "directus_key"
      "directus_secret"
      "directus_admin_email"
      "directus_admin_password"
    ] (_: { });

    systemd.tmpfiles.rules = [
      "d /var/lib/directus 0750 root root -"
      "d /var/lib/directus/database 0750 1000 1000 -"
      "d /var/lib/directus/uploads 0750 1000 1000 -"
      "d /var/lib/directus/extensions 0750 1000 1000 -"
      "d ${backupDirectory} 0700 root root -"
    ];

    virtualisation.oci-containers.containers.directus = {
      # Wait through the startup probe before switch-to-configuration inspects
      # failed transient units. An expected pre-readiness probe is not a failed
      # deployment, and the independent database check must pass before READY.
      podman.sdnotify = "healthy";
      # Keep upgrades explicit so a container restart cannot silently migrate the database.
      # Fresh-data/Core post-grace proof: docs/security-audit-2026-10-25-directus-fresh.md.
      image = "directus/directus:12.5.1@sha256:1a660be4c3634aae7b46153589e72c7ce02f2094ff061049ca1a5789c600e5da";

      environment = {
        DB_CLIENT = "sqlite3";
        DB_FILENAME = "/directus/database/data.db";
        # Knex 3.1 can return a failed SQLite COMMIT with its transaction still open.
        # Retire idle connections so that transaction rolls back and releases its locks.
        # Continued traffic can prevent retirement; independent DB health below
        # bounds recovery then. See the SQLite lock audit and real-image fixture.
        DB_POOL__MIN = "0";
        DB_POOL__MAX = "1";
        PUBLIC_URL = "https://${cfg.domain}";
        CORS_ENABLED = "false";
        # Unused by the website's server-side REST client. Keep the default explicit.
        WEBSOCKETS_ENABLED = "false";
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
        "--cap-drop=ALL"
        "--security-opt=no-new-privileges"
        "--health-cmd=${sqliteHealthCommand}"
        "--health-interval=30s"
        "--health-timeout=5s"
        "--health-retries=6"
        "--health-start-period=0s"
        # The separate startup gate provides migration grace. Podman 5.8 counts
        # no failures during a start-period, even after an earlier successful read.
        # Do not interrupt a legitimate migration before HTTP startup completes.
        # Startup failures are observable as 'starting', without a restart loop.
        "--health-startup-cmd=${startupHealthCommand}"
        "--health-startup-interval=10s"
        "--health-startup-timeout=5s"
        "--health-startup-retries=0"
        # Let the existing systemd Restart=on-failure own process replacement.
        "--health-on-failure=kill"
      ];
    };

    systemd.services.podman-directus.serviceConfig.RestartSec = "5s";

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
      path = [ pkgs.gzip ];
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
      path = [ pkgs.gzip ];
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
