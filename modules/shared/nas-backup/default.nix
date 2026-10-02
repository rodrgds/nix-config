# VPS-only transport; the NAS uses the restricted receiver documented alongside it.
{
  config,
  lib,
  pkgs,
  ...
}:
let
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
    "${pkgs.python3}/bin/python3 ${./sender.py} ${dataset} ${kind} ${lib.escapeShellArg producer}";
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
          ${
            if status == "" then
              send dataset kind producer
            else
              ''
                status=${lib.escapeShellArg status}
                trap 'rm -f "$status.tmp"' EXIT
                ${send dataset kind producer} > "$status.tmp"
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
    after = [
      "network-online.target"
    ];
    wants = [ "network-online.target" ];
    environment.NAS_BACKUP_SSH_KEY = config.sops.secrets.nas_backup_ssh_key.path;
    path = runtime;
    serviceConfig = {
      ExecStart = lib.mkForce "${pkgs.python3}/bin/python3 ${./restore_check.py} ${dataset}";
      RuntimeDirectory = name;
      ReadWritePaths = [
        "/run/${name}"
      ]
      ++ lib.optional (dataset == "openpost-db") "/var/backup/openpost";
      UMask = "0077";
      TimeoutStartSec = "7h";
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

}
