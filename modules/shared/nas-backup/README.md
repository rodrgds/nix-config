# Direct NAS backups

The VPS streams eight backup datasets over Tailscale. The production receiver routes `openpost-db` and `openpost-media` to `/volume1/openpost-private-backups/rgo-vps`. Other datasets continue using `/volume1/homes/kraktoos/Backups/rgo-vps`. Runtime relocation requires the operator steps below. Daily backup timers, weekly OpenPost and Directus restore checks, service dependencies and existing owner-specific failure alerts remain in their owning service modules. Full dumps and media mirrors are no longer written to the VPS. There is not yet a human alert route covering every dataset.

## Access

The dedicated SSH identity is encrypted as `nas_backup_ssh_key` in `secrets/vps-secrets.yaml` and installed by sops-nix. It is separate from the laptop and desktop login keys. SSH pins the NAS host key and falls back from `rgo-nas` to its Tailscale address `100.88.5.41` when DNS is unavailable.

Install `receiver.py` as root-owned `/usr/local/lib/nas-backup/receiver.py` on the NAS. Provision both backup roots with private DSM ACLs and ownership for `kraktoos` before switching the receiver. Authorize the dedicated public key in `/etc/ssh/authorized_keys/kraktoos` with:

```text
restrict,command="/usr/bin/python3 -I /usr/local/lib/nas-backup/receiver.py" ssh-ed25519 PUBLIC_KEY rgo-vps-nas-backup
```

Synology rejects this home's ACL during normal key lookup. Its SSH configuration therefore uses the root-owned key file for `kraktoos`. Preserve existing login keys when updating it. Install the receiver before rebuilding the VPS; restore checks need its restricted download command as well as upload.

### NAS permissions

Both backup trees must have private DSM ACLs as well as private Unix modes. The
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

Apply the same access restrictions to `/volume1/openpost-private-backups` and
its children. Verify that this private root is not shared, watched by Drive, or
copied by another sync job. Preserve the retention policy for other home files.

The forced key restricts commands, but still runs as an administrator who is in
the Docker group. A future separate backup account needs no Docker membership,
sudo, DSM applications or interactive login. Synology's restrictions on SSH
accounts must be verified before changing that identity. Keep the existing
forced command and host-key pinning until the replacement is proven.

## Integrity and recovery

A snapshot is published only after the whole producer succeeds and the NAS verifies its SHA-256, size, gzip checksum and, for archives, tar framing. Failed uploads cannot rotate successful backups. Each dataset retains at most seven successful snapshots. OpenPost database and media snapshots also expire six days after their receiver-issued UTC timestamp. An independent hourly prune removes expired OpenPost snapshots even when daily uploads fail, including the last remaining snapshot. Other datasets keep their seven-successful-snapshot policy without an age limit. Montra's status file is replaced only after a matching NAS receipt.

Uploads stage growing, unverified files under each dataset's `@tmp/` directory.
After sender success and verification, the receiver renames the snapshot into the
dataset root and synchronizes both directories. It removes abandoned partials
from `@tmp/` and the legacy root location while holding the dataset lock.
The hourly OpenPost prune also removes those abandoned partials under the same
lock, even when no later upload succeeds. It leaves an active upload untouched.

The six-day expiry applies to snapshots in this NAS backup tree. It does not
establish retention for Synology Drive versions, synchronized clients, recycle
bins, or other copies. Check those configurations separately before making a
retention claim about them.

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

OpenPost's older encrypted offsite job requires local backup files and cannot be enabled with this transport. A third-copy policy must consume NAS snapshots instead. Activation does not remove legacy backups or retired app data. OpenPost expiry applies at the selected receiver root; copies outside the private tree need an explicit reviewed cleanup.


## Route OpenPost backups outside Drive and enable expiry

The private root must be an unshared directory outside every Drive watch path.
Verify that configuration and its effective DSM ACL before installing this
receiver. Only `kraktoos` and administrators should have access. Durable
snapshots belong in the private dataset root, with `@tmp/` reserved for partial
streams. Do not use `@tmp/` as permanent backup storage.

Production `upload`, `download`, and `prune` commands use the private root for
the two OpenPost datasets. A missing or symlinked private root fails closed;
there is no fallback into the indexed homes tree. Dataset names, receipt labels,
and the forced SSH protocol stay unchanged. An explicit `--root` override keeps
all datasets under that supplied root for isolated tests or recovery work.

Runtime relocation is an operator action, not an automatic migration. The
receiver neither moves nor deletes legacy snapshots. After the switch, ordinary
OpenPost prune commands affect only the private tree. Use this rollout order:

1. Preserve the existing verified recovery copy. Deploy and verify OpenPost's
   data cleanup, then provision the private root with the access restrictions
   above. Verify sufficient capacity before changing the receiver.
2. Install this reviewed `receiver.py` as root-owned
   `/usr/local/lib/nas-backup/receiver.py`, mode `0755`. Preserve the forced SSH
   key command and compare the installed SHA-256 with the reviewed file.
3. Run `openpost-postgres-backup.service` and `openpost-media-backup.service`.
   Check successful results and fresh manifests in the private tree. Run
   `openpost-restore-drill.service` and verify it restores through the unchanged
   download protocol from that tree. Stop if either backup or restore fails.
4. Only after that proof, remove or migrate the specifically approved legacy
   OpenPost recovery copies through the reviewed operator procedure. Handle
   Drive versions, recycle bins, and any synchronized copies separately. The
   new storage route does not purge them or change other home files' retention.
5. Run only `prune openpost-db` and `prune openpost-media` through the dedicated
   identity. Confirm both JSON results and that fresh private snapshots remain.
   Apply the scoped Nix revision through the normal `rebuild --vps` workflow,
   verify `openpost-nas-backup-prune.timer`, and run its service once. Keep the
   existing freshness timer active.

The receiver rejects prune commands for every other dataset, arbitrary paths,
extra arguments and shell syntax. Prune takes the same exclusive dataset lock
as uploads, so it cannot remove an in-progress snapshot. A busy receiver causes
that prune attempt to fail and alert; the hourly timer retries. Upload sessions
remain bounded by the receiver's six-hour deadline.

For expiry independent of VPS availability, also install the maintained
`openpost-retention.sh` as root-owned
`/usr/local/lib/nas-backup/openpost-retention.sh`, mode `0755`, on the NAS. After
the same fresh-backup and restore gate, add this single idempotent entry to the
DSM root crontab, preserving every existing entry, and reload its cron service:

```cron
17 * * * * kraktoos /usr/local/lib/nas-backup/openpost-retention.sh
```

Run the script once as `kraktoos` and check both JSON results. This task runs
with the existing backup account's permissions and only expires the two
OpenPost datasets. Its errors go to the NAS system log. Keep this NAS-local
schedule when VPS service activation is unavailable; do not describe the
VPS-only timer as independent of VPS outages.

After the initial verified rollout, expiry does not require a newer successful
backup. This is deliberate: an outage must not retain expired recovery data
indefinitely. The freshness monitor alerts after 36 hours without a verified
transfer. If uploads remain broken, expiry can leave OpenPost without a NAS
recovery snapshot. Repair the producer or transport promptly instead of extending
the privacy deadline.

The declared hourly timer runs on the VPS and requires NAS SSH access. A VPS or
transport outage can delay expiry until connectivity returns. Enforcing expiry
while the VPS is offline requires a separately reviewed NAS-local scheduled task
using the same two restricted prune commands. The VPS freshness monitor cannot
prove expiry during its own outage.

## Freshness monitoring

Successful transfers atomically publish private receipts for all eight enabled
datasets under `/var/lib/nas-backup/receipts`. The hourly
`nas-backup-freshness.timer` checks for missing, malformed, future-dated or
older-than-36-hour receipts. Its first check runs 15 minutes after activation.
A receipt confirms the transfer, not a restore or an independent retained copy.

Failed backup jobs, restore checks and freshness checks notify the owner's
infrastructure Discord channel through `nas-backup-alert@.service`. Its dedicated
webhook is SOPS-encrypted and passed through a private systemd credential to a
sandboxed dynamic user. Messages contain only the hostname, failed unit, result
and time, with mentions disabled. Delivery requires Discord's message
acknowledgement; redirects are refused and retries are bounded. Notification
errors never print the credential-bearing URL or backup contents.

This does not replace the existing app-specific OpenPost notifications. A monitor
outside the VPS is still needed to detect the VPS itself being offline. To check
backup freshness manually:

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
