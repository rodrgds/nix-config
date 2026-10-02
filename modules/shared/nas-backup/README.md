# Direct NAS backups

The VPS streams eight backup datasets over Tailscale to `/volume1/homes/kraktoos/Backups/rgo-vps`. Daily backup timers, weekly OpenPost and Directus restore checks, service dependencies and failure alerts remain in their owning service modules. Full dumps and media mirrors are no longer written to the VPS.

## Access

The dedicated SSH identity is encrypted as `nas_backup_ssh_key` in `secrets/vps-secrets.yaml` and installed by sops-nix. It is separate from the laptop and desktop login keys. SSH pins the NAS host key and falls back from `rgo-nas` to its Tailscale address `100.88.5.41` when DNS is unavailable.

Install `receiver.py` as root-owned `/usr/local/lib/nas-backup/receiver.py` on the NAS. Create the backup root owned by `kraktoos`. Authorize the dedicated public key in `/etc/ssh/authorized_keys/kraktoos` with:

```text
restrict,command="/usr/bin/python3 -I /usr/local/lib/nas-backup/receiver.py" ssh-ed25519 PUBLIC_KEY rgo-vps-nas-backup
```

Synology rejects this home's ACL during normal key lookup. Its SSH configuration therefore uses the root-owned key file for `kraktoos`. Preserve existing login keys when updating it. Install the receiver before rebuilding the VPS; restore checks need its restricted download command as well as upload.

## Integrity and recovery

A snapshot is published only after the whole producer succeeds and the NAS verifies its SHA-256, size, gzip checksum and, for archives, tar framing. Failed uploads cannot rotate successful backups. Each dataset retains seven successful snapshots. Montra's status file is replaced only after a matching NAS receipt.

Each snapshot directory contains `data.gz` and `manifest.json`. Database datasets contain gzipped SQL. Media archives contain `media/` files. Vaultwarden and Directus archives contain ordered `database/00000000.sql` chunks and `files/` application data, excluding the live SQLite database and its WAL files. Concatenate the SQL chunks into sqlite3 on a new restore database, then restore the application files separately.

Media uses one boto3 client for paginated listings and streaming reads. Each read requires the listed ETag, and a final inventory comparison rejects changes made during the export.

The weekly checks download and verify NAS snapshots, restore Directus into a temporary SQLite database, and restore OpenPost into a disposable PostgreSQL database. OpenPost also checks its media archive and updates `/var/backup/openpost/restore-drill-latest.json`. Interrupted drills clean up their temporary database.

OpenPost's older encrypted offsite job requires local backup files and cannot be enabled with this transport. A third-copy policy must consume NAS snapshots instead. Historical backups and retired app data are not removed by activation.

## Validation

```bash
PYTHONDONTWRITEBYTECODE=1 nix shell --impure --expr '
  let pkgs = import (builtins.getFlake (toString ./.)).inputs.nixpkgs {
    system = builtins.currentSystem;
  };
  in pkgs.buildEnv {
    name = "nas-backup-test-runtime";
    paths = [ (pkgs.python3.withPackages (ps: [ ps.boto3 ]))
              pkgs.sqlite pkgs.gnutar pkgs.gzip pkgs.bash ];
  }
' -c python3 -m unittest discover -s tests -v
```

After receiver changes, install the matching receiver and run one backup plus its restore check. After transport or producer changes, run the affected jobs once and inspect their systemd results and NAS manifests. Existing timers cover subsequent runs.
