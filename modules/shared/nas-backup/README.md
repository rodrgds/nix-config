# Direct NAS backups

The VPS streams eight backup datasets over Tailscale to `/volume1/homes/kraktoos/Backups/rgo-vps`. Daily backup timers, weekly OpenPost and Directus restore checks, service dependencies and existing owner-specific failure alerts remain in their owning service modules. Full dumps and media mirrors are no longer written to the VPS. There is not yet a human alert route covering every dataset.

## Access

The dedicated SSH identity is encrypted as `nas_backup_ssh_key` in `secrets/vps-secrets.yaml` and installed by sops-nix. It is separate from the laptop and desktop login keys. SSH pins the NAS host key and falls back from `rgo-nas` to its Tailscale address `100.88.5.41` when DNS is unavailable.

Install `receiver.py` as root-owned `/usr/local/lib/nas-backup/receiver.py` on the NAS. Create the backup root owned by `kraktoos`. Authorize the dedicated public key in `/etc/ssh/authorized_keys/kraktoos` with:

```text
restrict,command="/usr/bin/python3 -I /usr/local/lib/nas-backup/receiver.py" ssh-ed25519 PUBLIC_KEY rgo-vps-nas-backup
```

Synology rejects this home's ACL during normal key lookup. Its SSH configuration therefore uses the root-owned key file for `kraktoos`. Preserve existing login keys when updating it. Install the receiver before rebuilding the VPS; restore checks need its restricted download command as well as upload.

### NAS permissions

The backup tree must have a private DSM ACL as well as private Unix modes. The
October 2026 audit found that inheritance from the home folder gave
`sc-syncthing` full access to every snapshot, overriding the privacy intended by
`mkdir(..., 0700)` and file mode `0600`. A `0777` result from `stat` on Synology
does not alone establish effective access. Inspect `synoacltool -get` on the
root, a dataset, a snapshot directory and `data.gz`.

In DSM File Station's permission editor, disable inheritance specifically on
`/volume1/homes/kraktoos/Backups/rgo-vps`, convert the inherited rules, and remove
the Syncthing service and every unrelated principal. Keep backup account
`kraktoos` and administrators, and apply the private policy to existing child
folders and files. Review any explicit child rules as well. Do not change the
whole home folder or delete snapshots. Verify the effective ACL on all eight
datasets and representative files afterwards. The root-owned receiver and
root-owned authorized key file remain outside this writable data tree.

The forced key restricts commands, but still runs as an administrator who is in
the Docker group. A future separate backup account needs no Docker membership,
sudo, DSM applications or interactive login. Synology's restrictions on SSH
accounts must be verified before changing that identity. Keep the existing
forced command and host-key pinning until the replacement is proven.

## Integrity and recovery

A snapshot is published only after the whole producer succeeds and the NAS verifies its SHA-256, size, gzip checksum and, for archives, tar framing. Failed uploads cannot rotate successful backups. Each dataset retains seven successful snapshots. Montra's status file is replaced only after a matching NAS receipt.

Each snapshot directory contains `data.gz` and `manifest.json`. Database datasets contain gzipped SQL. Media archives contain `media/` files. Vaultwarden and Directus archives contain ordered `database/00000000.sql` chunks and `files/` application data, excluding the live SQLite database and its WAL files. Concatenate the SQL chunks into sqlite3 on a new restore database, then restore the application files separately.

The receiver accepts at most 16 GiB compressed and 128 GiB expanded per upload.
It rejects a transfer before writing the frame that exceeds the compressed
limit, and bounds gzip verification reads at the expanded limit. Rejection
removes only the failed partial and leaves successful snapshots untouched.
These budgets leave headroom over the October 2026 largest snapshot, about
4 GiB compressed. Review legitimate growth before raising them. They supplement
the six-hour timeout; they do not replace a NAS storage quota, a private ACL or
an independent backup copy. The Linux receiver also enforces a hard 512 MiB
address-space ceiling, 64 descriptors and disabled core dumps before reading
input. Tar parsing bounds physical headers, metadata, recursion and paths, and
does not retain every parsed member. These are per-process budgets, not an
aggregate SSH/NAS resource quota. See the receiver-resource audit supplement
for exact capacities and Python 3.8 compatibility evidence.

Media uses one boto3 client for paginated listings and streaming reads. Each read requires the listed ETag, and a final inventory comparison rejects changes made during the export.

The weekly checks download and verify NAS snapshots, restore Directus into a temporary SQLite database, and restore OpenPost into a disposable PostgreSQL database. OpenPost also checks its media archive and updates `/var/backup/openpost/restore-drill-latest.json`. Interrupted drills remove their disposable container; systemd also has a CID-based stop fallback.

The SQLite checker runs the CLI with `--safe`, suppresses SQL diagnostics and
results, and rejects shell directives, database attachment and external output
files. Never add a safe-mode escape nonce. This protects against a NAS writer
replacing an archive and its checksum together. See SQLite's
[safe-mode contract](https://sqlite.org/cli.html#the_safe_command_line_option).
The PostgreSQL server and psql client run in a disposable digest-pinned Alpine container, with no network, production volumes, host mounts or credentials. Its root filesystem is read-only, it runs as postgres with no capabilities, and temporary storage, memory, CPU and process counts are bounded. A separate database inside a production container is not an acceptable substitute. See the dated audit reports for isolation regression evidence and current host-side staging limits.

OpenPost's older encrypted offsite job requires local backup files and cannot be enabled with this transport. A third-copy policy must consume NAS snapshots instead. Historical backups and retired app data are not removed by activation.

## Freshness monitoring

Successful transfers atomically publish private receipts for all eight enabled
datasets under `/var/lib/nas-backup/receipts`. The hourly
`nas-backup-freshness.timer` checks for missing, malformed, future-dated or
older-than-36-hour receipts. Its first check runs 15 minutes after activation.
A receipt confirms the transfer, not a restore or an independent retained copy.

The monitor currently reports through its systemd result and journal. Human
delivery needs an approved destination and a separately provisioned credential;
do not reuse an application's webhook without authorization. A monitor outside
the VPS is also needed to detect the VPS itself being offline. Until those are
configured, run this check and inspect the result at least daily:

```bash
ssh rgo@rgo-vps 'sudo systemctl start nas-backup-freshness.service && sudo journalctl -u nas-backup-freshness.service -n 20 --no-pager'
```

On failure, inspect the named dataset's backup unit and latest NAS manifest,
repair the cause and rerun the ordinary job. Do not replace a failed receipt
manually or reset failures to imply that a backup succeeded.

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
