# VPS-only transport; the NAS uses the restricted receiver documented alongside it.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  receiptDirectory = "/var/lib/nas-backup/receipts";
  freshness = "${pkgs.python3}/bin/python3 ${./freshness.py} --state-dir ${receiptDirectory}";
  expectedDatasets =
    lib.optional config.vps.montra.enable "montra-db:gzip"
    ++ lib.optionals (config.vps.openpost.enable && config.vps.openpost.edition == "cloud") [
      "openpost-db:gzip"
      "openpost-media:tar-gzip"
    ]
    ++ lib.optional config.vps.vaultwarden.enable "vaultwarden:tar-gzip"
    ++ lib.optional config.vps.directus.enable "directus:tar-gzip"
    ++ lib.optional config.vps.umami.enable "umami-db:gzip"
    ++ lib.optional config.vps.shlink.enable "shlink-db:gzip"
    ++ lib.optional config.vps.unprompted.enable "unprompted-db:gzip";
  mediaPython = pkgs.python3.withPackages (ps: [ ps.boto3 ]);
  runtime = [
    pkgs.bash
    pkgs.openssh
    pkgs.python3
    pkgs.podman
    pkgs.gzip
    pkgs.coreutils
    pkgs.util-linux
    pkgs.sqlite
  ];
  send =
    dataset: kind: producer:
    "${freshness} record ${dataset} ${kind} -- ${pkgs.python3}/bin/python3 ${./sender.py} ${dataset} ${kind} ${lib.escapeShellArg producer}";
  sqliteArchive =
    root: database:
    "${pkgs.python3}/bin/python3 ${./sqlite_archive.py} ${lib.escapeShellArg root} ${lib.escapeShellArg database}";
  job = name: dataset: kind: producer: status: {
    after = [
      "network-online.target"
    ];
    wants = [ "network-online.target" ];
    environment.NAS_BACKUP_SSH_KEY = config.sops.secrets.nas_backup_ssh_key.path;
    path = runtime;
    # Explicit ExecStart overrides must not retain a generated script command.
    script = lib.mkForce "";
    serviceConfig = {
      ExecStart = lib.mkForce (
        pkgs.writeShellScript name ''
          set -euo pipefail
          umask 077
          exec 9>/var/lib/nas-backup/transfer.lock
          flock 9
          ${send dataset kind producer}
          ${
            if status == "" then
              ""
            else
              ''
                status=${lib.escapeShellArg status}
                trap 'rm -f "$status.tmp"' EXIT
                # Preserve Montra's existing app-readable compatibility status.
                # The canonical freshness receipt stays private under nas-backup.
                cat ${receiptDirectory}/${dataset}.json > "$status.tmp"
                chmod 0644 "$status.tmp"
                mv "$status.tmp" "$status"
              ''
          }
        ''
      );
      Type = "oneshot";
      UMask = "0077";
      StateDirectory = "nas-backup";
      StateDirectoryMode = "0700";
      ReadWritePaths = [
        "/var/lib/nas-backup"
      ]
      ++ lib.optional (status != "") "/var/lib/montra/backup-status";
      TimeoutStartSec = "7h";
      Nice = 10;
      IOSchedulingClass = "idle";
    };
  };
  restoreJob = name: dataset: {
    # NAS restores only need transport, never start a production database.
    after = lib.mkForce [ "network-online.target" ];
    requires = lib.mkForce [ ];
    wants = [ "network-online.target" ];
    environment = {
      NAS_BACKUP_SSH_KEY = config.sops.secrets.nas_backup_ssh_key.path;
    }
    // lib.optionalAttrs (dataset == "openpost-db") {
      NAS_RESTORE_POSTGRES_IMAGE =
        config.virtualisation.oci-containers.containers.openpost-postgres.image;
      NAS_RESTORE_CONTAINER_CIDFILE = "/run/${name}/postgres.cid";
    };
    path = runtime;
    serviceConfig = {
      ExecStart = lib.mkForce "${pkgs.python3}/bin/python3 ${./restore_check.py} ${dataset}";
      RuntimeDirectory = name;
      RuntimeDirectoryMode = "0700";
      # Compressed archives go to private disk, not the shared /run tmpfs.
      CacheDirectory = name;
      CacheDirectoryMode = "0700";
      ExecStartPre = "${pkgs.coreutils}/bin/rm -rf -- /var/cache/${name}/staging";
      ReadWritePaths = [
        "/run/${name}"
        "/var/cache/${name}"
      ]
      ++ lib.optional (dataset == "openpost-db") "/var/backup/openpost";
      UMask = "0077";
      TimeoutStartSec = "7h";
      # These constrain host Python/ssh/sqlite/Podman clients. The disposable
      # PG payload remains in machine.slice with its own 1536 MiB cgroup, so a
      # host OOM cannot trap cleanup under a shared exhausted memory budget.
      MemoryMax = "512M";
      MemorySwapMax = 0;
      CPUQuota = "75%";
      TasksMax = 64;
      LimitNOFILE = 128;
      LimitFSIZE = "768M";
      LimitCORE = 0;
      OOMPolicy = "stop";
      KillMode = "mixed";
      TimeoutStopSec = "60s";
      # systemd runs both after success, interpreter death, timeout or SIGKILL.
      # Never put the host-owned CID inside archive or staging-controlled state.
      ExecStopPost =
        lib.optional (
          dataset == "openpost-db"
        ) "-${pkgs.podman}/bin/podman rm --force --ignore --cidfile /run/${name}/postgres.cid"
        ++ [ "${pkgs.coreutils}/bin/rm -rf -- /var/cache/${name}/staging" ];
    };
  };
in
{
  sops.secrets.nas_backup_ssh_key.mode = "0600";
  assertions = [
    {
      assertion = !config.vps.openpost.offsiteBackup.enable;
      message = "NAS streaming backups cannot use OpenPost's local-file offsite job. Back up NAS snapshots separately before enabling a third-copy policy.";
    }
  ];
  environment.etc."nas-backup/known_hosts".text = ''
    rgo-nas,100.88.5.41 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMyZkJe7c8stOA3jvquyqzrn89utxNq/MeHrmiemAltG
  '';
  systemd.services = lib.mkMerge [
    (lib.mkIf (expectedDatasets != [ ]) {
      nas-backup-freshness = {
        description = "Check verified NAS backup receipt freshness (not restore drills)";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${freshness} check ${lib.escapeShellArgs expectedDatasets}";
          StateDirectory = "nas-backup";
          StateDirectoryMode = "0700";
          UMask = "0077";
          User = "root";
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          PrivateNetwork = true;
          TimeoutStartSec = "1min";
          MemoryMax = "64M";
          TasksMax = 8;
          StandardOutput = "journal";
          StandardError = "journal";
          SyslogIdentifier = "nas-backup-freshness";
        };
      };
    })
    (lib.mkIf config.vps.montra.enable {
      montra-postgres-backup =
        job "montra-postgres-backup" "montra-db" "gzip"
          "podman exec montra-postgres pg_dump -U montra -d montra | gzip"
          "/var/lib/montra/backup-status/status.json";
    })
    (lib.mkIf (config.vps.openpost.enable && config.vps.openpost.edition == "cloud") {
      openpost-postgres-backup =
        job "openpost-postgres-backup" "openpost-db" "gzip"
          "podman exec openpost-postgres pg_dump -U openpost -d openpost | gzip"
          "";
      openpost-media-backup =
        job "openpost-media-backup" "openpost-media" "tar-gzip" "${mediaPython}/bin/python3 ${./media.py}"
          "";
      openpost-restore-drill = restoreJob "openpost-restore-drill" "openpost-db";
    })
    (lib.mkIf config.vps.vaultwarden.enable {
      vaultwarden-backup =
        job "vaultwarden-backup" "vaultwarden" "tar-gzip"
          (sqliteArchive "/var/lib/vaultwarden/data" "db.sqlite3")
          "";
    })
    (lib.mkIf config.vps.directus.enable {
      directus-backup =
        job "directus-backup" "directus" "tar-gzip" (sqliteArchive "/var/lib/directus" "database/data.db")
          "";
      directus-backup-check = restoreJob "directus-backup-check" "directus";
    })
    (lib.mkIf config.vps.umami.enable {
      umami-postgres-backup = job "umami-postgres-backup" "umami-db" "gzip" ''
        user=$(cat ${config.sops.templates.umami-db-user.path})
        database=$(cat ${config.sops.templates.umami-db-name.path})
        podman exec umami-postgres pg_dump -U "$user" -d "$database" | gzip
      '' "";
    })
    (lib.mkIf config.vps.shlink.enable {
      shlink-backup =
        job "shlink-backup" "shlink-db" "gzip" "podman exec shlink-postgres pg_dumpall -U shlink | gzip"
          "";
    })
    (lib.mkIf config.vps.unprompted.enable {
      unprompted-postgres-backup =
        job "unprompted-postgres-backup" "unprompted-db" "gzip"
          "podman exec unprompted-postgres pg_dump -U unprompted -d unprompted --no-owner --no-privileges | gzip --best"
          "";
    })
  ];
  systemd.timers.nas-backup-freshness = lib.mkIf (expectedDatasets != [ ]) {
    description = "Monitor daily NAS backups with a 36-hour freshness deadline";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnActiveSec = "15min";
      OnUnitActiveSec = "1h";
      AccuracySec = "1min";
    };
  };
}
