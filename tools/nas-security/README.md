# NAS security administration

This is a reviewed procedure for the DSM NAS, not a Nix host activation.
Prepared on 2026-10-25 from read-only inspection. Do not run the change steps
until the parent rollout owner has integrated the source changes and agreed
the NAS maintenance window. No command in the inspection section changes a
service or reads credential values. Privileged commands below require the
human administrator's own `sudo` authentication.

## Inspect and preserve recovery access

From this checkout:

```sh
ssh -o BatchMode=yes kraktoos@rgo-nas /usr/bin/python3 - < tools/nas-security/verify-backup-acl.py
ssh -t kraktoos@rgo-nas
```

The first command is read-only. Exit 1 means the ACL policy needs review; exit
2 means inspection could not complete. The verifier checks every ordinary
file/directory under the backup root, including `archives` and `imports`, up to
10,000 paths. It rejects symlinks, unexpected principals and unknown tool
output. It does not read any backup content, alter an ACL, test effective
identity permissions, or claim the backups are complete/current. Run again
with sudo on an installed reviewed copy if metadata inspection is denied.

Keep the SSH session and a DSM session at `https://192.168.1.100:5001` open.
Verify the NAS certificate identity instead of bypassing TLS checks. Use a
second allowed session for recovery checks throughout the firewall and update
work. Inside the interactive NAS shell:

```sh
sudo -v
sudo /sbin/iptables -S
sudo /sbin/ip6tables -S
sudo /usr/syno/bin/synoacltool -get-perm /volume1/homes/kraktoos/Backups/rgo-vps sc-syncthing
sudo /usr/syno/bin/synoacltool -get-perm /volume1/homes/kraktoos/Backups/rgo-vps kraktoos
sudo /usr/syno/bin/synoacltool -get-perm /volume1/homes/kraktoos/Backups kraktoos
sudo /usr/syno/bin/synoacltool -get-perm /volume1/homes/kraktoos/Backups sc-syncthing
```

The installed ACL tool documents `-get`, `-get-perm PATH USERNAME`,
`-set-archive`, `-del-archive`, `-enforce-inherit` and indexed ACE deletion.
Unprivileged effective-user checks fail with `failed to initgroup`; that is an
inspection limit, not a permission denial. The reviewed command procedure below
uses parsed ACEs and inode-anchored targets, rather than hardcoded ACE indices.
Its native DSM fixtures verify inheritance, preservation and exact rollback.

Do not use the Docker socket or any stored `SUDO_PASSWORD` to obtain root.
Do not print `docker inspect` wholesale, `env`, `.env`, Docker credentials,
authorized key lines or application configuration containing credentials.

## Isolate backup ACLs, NAS-03

### Reviewed commands for the confirmed Syncthing layout

The owner confirmed three Syncthing roots: `Development`, `University` and
`/volume1/jdsystem`. Syncthing is stopped. `restrict-backup-acl.py --apply`
verifies that configuration and tests a synthetic tree first. It preserves
explicit access to Development/University and leaves jdsystem untouched. It
removes home-wide Syncthing authority, retaining home traversal, and isolates
the eight-dataset backup subtree. It does not change file data or the firewall.
Three existing Linux-mode legacy objects are already private to the backup
account. Their modes, owners and format are verified and preserved, not converted
to DSM ACLs. Both the repair and metadata verifier recognize this case.

Install the reviewed script as a root-owned file, verify its reviewed SHA-256
after installation, then run it with the administrator's own sudo authentication:

```sh
sudo /usr/bin/python3 /usr/local/lib/rgo-security/restrict-backup-acl.py --apply
```

The parent supplies the exact staged path and hash. No credential is in the
script. It requires an idle upload window and holds all eight receiver locks.
Unknown ACL entries, custom deny rules, links, replaced objects or unexpected
configuration stop the repair. Root checks actual Syncthing access in the
disposable fixture, then effective ACLs for the live folders. Root-only
permission checks have not been claimed from an unprivileged fixture run.
The synthetic home sits inside a private outer directory with traverse-only
Syncthing access. DSM derives effective delete permission from a parent's
delete-child grant, so testing directly beneath the still-unmodified live
home would fail before the repair. The root fixture also verifies actual
Syncthing rename denial at the synthetic home and backup ancestors.

Recovery policies are retained under `/volume1/docker/rgo-security-acl/policy-*`.
A failed acceptance restores the original ACLs. For a later explicit rollback,
use the exact journal directory printed by the successful apply:

```sh
sudo /usr/bin/python3 /usr/local/lib/rgo-security/restrict-backup-acl.py --rollback /volume1/docker/rgo-security-acl/policy-EXACT_DIRECTORY
```

Rollback validates every live object and saved ACL before changing any policy;
retention removing an old snapshot aborts without restoring broad home access.
The native missing-target regression demonstrated that failure before the fix
and passed afterward. Keep the recovery directory for diagnosis if a check fails.

### DSM interface alternative

Use File Station and select **only**
`homes/kraktoos/Backups/rgo-vps`, Properties, Permission, Advanced options.
Disable inheritance and convert inherited permissions to explicit entries so
the administrator and backup account retain access during the transition.
Keep full control for `kraktoos` and recovery access for `administrators` and
root. For the folder and every descendant, remove the allow entries for
`sc-syncthing`, `hermesaccess`, `everyone` and generic owner grants. Retain the
named backup/admin entries. Apply the reviewed policy to existing child files
and folders, including explicit child entries, not only to new children.
Do not recursively change the whole home or `homes` shared folder.

The verifier's private policy accepts only named allows for `user:kraktoos`,
`user:root`, and `group:administrators`. It requires full backup-account rights
and administrator recovery rights on each object, and no parent inheritance
on the backup root. Deny rules require separate effective-access review.
Inherited rules *inside* the private backup subtree are expected.

The home and `Backups` ancestors currently grant Syncthing full rights too.
Inspect effective delete, delete-child, rename and permission-change rights on
those ancestors. A private descendant ACL alone does not prove ancestor
rename/deletion resistance. Resolve these rights with DSM Permission Inspector
while preserving the user's actual Syncthing folders. If that cannot be done
without breaking those folders, migrate to a dedicated private backup shared
folder with the parent, updating the receiver root and its provisioning source
together. Do not silently move data or change the forced receiver path.

After the UI change, rerun the verifier. Use the privileged `-get-perm` commands
above at root, dataset, snapshot and `data.gz`/`manifest.json` levels, plus
Permission Inspector for `sc-syncthing` and the retained account. Syncthing must
have no data read/write/delete/ACL-change rights; the backup account must retain
the required rights. Select the actual newest snapshot in File Station; no
stale snapshot path is hardcoded here. Ask the parent to run one normal backup
and its isolated restore drill after integration. Do not treat a metadata-only
pass as a successful backup or restore.

Synology documents the [File Station permission editor](https://kb.synology.com/en-global/DSM/help/FileStation/privilege?version=7)
and [ACL precedence and inheritance](https://kb.synology.com/en-eu/DSM/tutorial/How_to_manage_ACL_settings_on_your_Synology_NAS).

## DSM firewall and network services, NAS-02/07

The NAS LAN address is `192.168.1.100` on `ovs_eth0`. Tailscale reports
`100.88.5.41`; this SSH connection is proxied to loopback and the interface
inventory has no `tailscale0`. Do not invent a `tailscale0` firewall rule or
assume a rule for `100.64.0.0/10` identifies the administrator. Tailnet access
control is a separate identity boundary. Inspect the privileged kernel rules
and confirm a second Tailscale session before applying DSM rules.

In Control Panel, Security, Firewall, create a new named profile with these
ordered rules, following the [vendor workflow](https://kb.synology.com/index.php/en-us/DSM/help/DSM/AdminCenter/connection_security_firewall?version=7):

The owner requires whole-home-LAN DSM access for family members and continued
QuickConnect access. The reviewed profile therefore uses the following policy,
rather than an allowlist of individual home devices:

| Traffic | Sources to record before enabling | Destination policy |
| --- | --- | --- |
| Home LAN | Actual IPv4 subnet and current on-link global IPv6 prefix | All ports on the LAN interfaces, including family DSM/file/app access |
| IPv6 link-local | `fe80::/10` on LAN interfaces | Preserve local router/discovery traffic |
| Tailscale transport | All sources | UDP 41641, not public SSH or DSM |
| Existing torrent peers | All sources | TCP/UDP 6881, retaining the existing published peer port |
| ICMP | All sources | Preserve diagnostics and network control traffic |
| Other unsolicited traffic | Other sources on physical, PPPoE and VPN interfaces | Default deny, IPv4 and IPv6 |
| Loopback and container bridges | Existing local paths | No global default-deny rule; verify the forwarding boundary separately |

Keep the original profile for recovery. Author a separate profile in DSM, save
it inactive, read it back, then select and apply it. Do not edit generated
firewall JSON or infer import schemas from CLI help. The installed CLI supports
`--enable`, `--disable`, `--reload`, `--export` and `--import`, but help alone
does not establish a safe profile-authoring/import contract.

An ISP-delegated IPv6 prefix can change. Update its LAN allowance after a prefix
change; IPv4 LAN access remains available. Keep loopback and required
container/tunnel upstream connectivity working. Preserve normal outbound and
established traffic. Verify QuickConnect relay and the required application
permissions without changing the family's service selections. Test a fresh
QuickConnect login on mobile data with both Wi-Fi and Tailscale off.

After applying, inspect the effective IPv4 and IPv6 rules using the human
administrator's own sudo authentication:

```sh
sudo /sbin/iptables -S
sudo /sbin/ip6tables -S
```

If recovery is necessary, from the retained LAN SSH session, the verified DSM
CLI can restore the previous disabled-firewall state:

```sh
sudo /usr/syno/bin/synofirewall --disable
```

Administrative/app ports requiring explicit containment include `9000/8000`
(Portainer), `9119` (Hermes), `20128` (9Router), `8888/9999` (Hindsight), and
`8191/8192` (browser solvers). Inventory other published ports before closing
them. Prefer loopback/private bindings plus authenticated HTTPS access for
management UIs. Change 9Router's secure-cookie setting only with its verified
HTTPS client origin. Disable password SSH only after verifying every human
key, the forced backup key and a local recovery path. Inspect DSM account/MFA,
auto-block and `admin` account status in the UI; no disabled-account assumption.

Docker-published traffic can bypass an INPUT-only policy. The existing
[Docker forwarding boundary](https://docs.docker.com/engine/network/packet-filtering-firewalls/)
needs explicit verification alongside DSM's policy. Do not flush Docker rules.
After applying, establish fresh allowed SSH/DSM/file-client sessions, require
the parent backup to succeed, and test denial from outside the allowed LAN.
Check public IPv6 from an external IPv6-capable vantage and inspect the router's
IPv4 forwarding, IPv6 ingress and UPnP mappings. The VPS has no usable route
for that external IPv6 test; this is still an administrator task.

## Hermes authority migration, NAS-01

The owner's current priority is broad, useful Hermes access. Retain its current
capabilities for now; the stages below describe a possible future migration,
not an instruction to remove access. Any change must first establish and
preserve the required workflows. Its NAS administrator and Docker authority
remain a backup trust boundary that ordinary backup ACLs cannot contain.

The live project is `/volume1/docker/hermes/compose.yml`, Compose project
`hermes`, with Docker Compose `v2.20.1-6047-g6817716`. It uses local image
`local/hermes-agent:uid1026-direct`, currently image ID
`sha256:1aa58efc5215ffe7a27be22fbe9c9c179afabeafacfed5283bc2c4e67e01d769`.
Do not pull or rebuild `latest` during a security-only migration. Preserve the
existing image and protected copies of the private data/manifest before rollout.
Never copy the raw manifest or private env files into Git.

The image's `/opt/hermes/docker/entrypoint-dispatch.sh` starts s6. Its stage2
hook does UID remapping, state initialization and ownership repair as root.
Its main wrapper and patched dashboard run script then use `s6-setuidgid hermes`.
The baked `hermes` UID/GID is `1026:100`, the NAS administrator's identity, with
group `65536` added for the Docker socket. Changing Compose to `user:1026:100`
or dropping all capabilities without an initialization strategy is not a
verified compatible fix. Bypassing s6 would also remove dashboard supervision.

Complete this staged migration with a reviewed application change, not a blind
production override:

1. Inventory each profile's required tools, writable roots, authentication and
   dashboard/Discord/Telegram behavior. Identify tasks that currently require
   host Docker or `sudo`; replace them with a narrow administrator-owned path.
2. Build a nonroot-compatible image for a **distinct non-admin DSM identity**,
   and prove s6/bootstrap and dashboard behavior using disposable state. Do not
   chown the existing home, University, Development or jdsystem trees wholesale.
3. Remove `/var/run/docker.sock`, `group_add: 65536` and the `SUDO_PASSWORD`
   runtime key. Remove every readable copy of that credential from private
   runtime state, preserving unrelated credentials. An empty env override is
   insufficient when `/opt/data` exposes the underlying credential file.
   Materialize replacement scoped credentials through SOPS at runtime. The
   current repository has no DSM secret-materialization mechanism, so wire it
   as part of that migration, without a secret in a derivation or command argv.
4. Preserve profile state, code wrappers and five read-only patches. Current
   mounts include `/opt/data`, writable `/nix`, `/workspace`, University,
   Development and jdsystem; narrow/remove each mount according to step 1.
   Bind-mounted read-only wrappers live *inside writable agent data*, which is
   not an administrator-owned executable boundary.
5. Replace host networking only after mapping loopback service dependencies.
   Publish the dashboard to the selected private interface. Keep a bridge path
   to 9Router/Hindsight/MCP upstreams and verify profile clients. Add
   `cap_drop: [ALL]`, `no-new-privileges` and resource limits once the new
   bootstrap/browser behavior is proved. A single 822 MiB sample is not a safe
   peak-memory limit; NAS CPU quotas are unsupported.
6. Migrate `hermes-watchdog` and `hermes-db-health` out of agent-accessible
   socket containers. The former restarts/starts the fixed `hermes` target on
   repeated HTTP/process failures. The latter performs SQLite WAL checkpoint,
   `PRAGMA optimize` and Discord alerting through `docker exec`; it is not just
   a passive health probe. Reimplement reviewed fixed-target maintenance in
   root-owned DSM tasks outside all agent mounts, with concurrency/stop policy
   and bounded commands, before retiring the sidecars. Their current scripts
   are under agent-accessible `/volume1/docker/hermes/maintenance`.

Acceptance requires a distinct non-admin runtime identity, no Docker API or
host sudo credential, narrowed mounts and profile credentials, working gateway
and dashboard, ordinary browser/tools/state writes, clean restart/shutdown and
replacement maintenance. Keep NAS-01 open until that live evidence exists.

## DSM, Tailscale and legacy packages, NAS-08

Live DSM is `7.3.2-86009` Update 4, Container Manager `24.0.2-1606`,
Tailscale `1.58.2-700058002`. Synology lists security Update 5 dated 2026-10-12
with a reboot in its [release notes](https://www.synology.com/en-global/releaseNote/DSM).
Use Control Panel, Update & Restore, DSM Update for the DS420+-compatible
patch in the maintenance window, with verified backups and LAN recovery.
Then update compatible Package Center packages and verify all required apps,
receiver permissions/hash, firewall, tailnet connectivity and Montra's stopped
updater state. Do not use an unattended bulk `synopkg upgradeall`.

The installed Tailscale binary supports `update --dry-run` and `update --yes`.
From the interactive NAS administrator session, after integration and with LAN
recovery available:

```sh
sudo /var/packages/Tailscale/target/bin/tailscale update --dry-run
sudo /var/packages/Tailscale/target/bin/tailscale update --yes
/var/packages/Tailscale/target/bin/tailscale version
/var/packages/Tailscale/target/bin/tailscale ip -4
```

The update may interrupt Tailscale transport. Reconnect and prove fresh
connectivity. For ongoing updates, the [vendor Synology procedure](https://tailscale.com/docs/integrations/synology)
uses a root DSM Task Scheduler job running `tailscale update --yes` at an
agreed maintenance time. Use the full binary path above. Do not enable it
without agreeing that update/reconnect policy.

These exact installed package names have **no declared `synopkg` dependents**
in this snapshot:

```sh
/usr/syno/bin/synopkg list --depend-on PHP7.3
/usr/syno/bin/synopkg list --depend-on PHP8.0
/usr/syno/bin/synopkg list --depend-on Node.js_v16
/usr/syno/bin/synopkg list --depend-on Node.js_v18
/usr/syno/bin/synopkg list --depend-on Python2
/usr/syno/bin/synopkg list --depend-on python38
```

That is insufficient proof they are unused. Web Station still has a named
Nextcloud PHP 8 profile and legacy PHP profiles. Verify the Web Service Portal,
script-language profiles, DSM scheduled tasks and native process executable
paths with administrator visibility before uninstalling a runtime in Package
Center. Some process paths were unreadable to the audit user. Leave current
Node 20/22 dependencies intact. In particular, the backup forced command uses
DSM `/usr/bin/python3`, resolving to `/usr/bin/python3.8`; **do not remove or
replace that system executable**. The SynoCommunity `python38` package is a
different installation. No runtime uninstall command is authorized by this
dependency inventory alone.

## Retention independent of the writer

The receiver retains seven replaceable snapshots. A checksum stored beside an
archive is not authenticity against another writer. Private ACLs reduce one
writer's access; they do not isolate backups from a NAS administrator or the
current Hermes identity/daemon authority.

Configure an independently administered encrypted off-NAS destination, with
destination-side immutability/retention and credentials unavailable to Hermes,
Syncthing and the VPS backup sender. The destination/account and retention
budget must be selected by the owner before an exact job can be prepared.
Use a reviewed DSM Hyper Backup or equivalent procedure for the backup subtree,
then prove a restore from that independent copy.

DS420+ appears in Synology's current [immutable snapshot model list](https://kb.synology.com/en-af/DSM/tutorial/which_synology_nas_models_support_WriteOnce_and_secure_snapshots).
Snapshot Replication is installed, but its configured schedules/immutability
were not available in this unprivileged review. In its UI, inspect whether the
containing shared folder supports immutable snapshots on this firmware, its
retention and remaining space before enabling a reviewed schedule. Immutable
snapshots of `homes` have a broader storage/retention scope than this subtree;
prefer a dedicated backup shared folder if that scope is inappropriate.
Snapshots on this NAS do not replace an independent off-NAS recovery copy.

## Public tunnel authentication

The `home-nas` tunnel routes Jellyfin at `watch.kraktoos.com`, Vikunja at
`tasks.rgo.pt`, Hindsight at `memory.rgo.pt`, and Karakeep web/MCP at
`mind.rgo.pt` (`/mcp` selects the MCP bridge). Keep the terminal 404 rule.
The audit found no Access applications. Existing app APIs returned 401 without
credentials, including the MCP initialize route; do not treat public login
pages or API documentation as a data-access bypass.

In Cloudflare Zero Trust, create narrowly scoped Access applications/policies
for the human-facing private UIs after testing actual users. Do not place an
interactive login redirect in front of MCP or Hindsight API clients without
first provisioning compatible service-token/OAuth access. Preserve native
mobile clients and Jellyfin playback authentication. The Jellyfin hostname's
TLS/DNS route still needs repair/verification before an authentication claim.
DNS/zone settings returned 403 in the audit, so the account owner must verify
that route and grant the narrowly required inspection capability.

After an authorized Access rollout, test both denied unauthenticated requests
and successful authorized browser/API/MCP/mobile flows. Never remove
application authentication just because Access exists. No tunnel or Access
mutation was made by this work.

## Montra worker

Follow the [owned worker procedure](../../modules/services/montra/nas/README.md).
Apply its existing privilege hardening with the current image pinned, recreate
only `worker`, and prove readiness plus one ordinary browser/scrape/state task.
The updater must remain stopped unless the rollout owner explicitly resolves
its enablement. A profile changes Compose selection, not an existing restart
policy. Socket authority remains unresolved for any future updater enablement.

For the reviewed October 25 hardening, the manifest is already staged on the
NAS. The exact-image disposable browser fixtures passed. In the interactive
NAS administrator shell, install and apply only that manifest:

```sh
set -eu
cd /volume1/docker/montra-catalog-worker
test "$(/usr/local/bin/docker inspect --format '{{.State.Running}}' montra-catalog-updater)" = false
echo 'e238ca1ecc6095ff2498cd0c3280fad0ba4a7e99fc6efdaf1324148500fdf54a  /tmp/rgo-montra-security.CxzpRzUL/compose.yaml' | sha256sum -c -
current_image=$(/usr/local/bin/docker inspect --format '{{.Image}}' montra-catalog-worker)
sudo test ! -e compose.yaml.pre-security-20261025
sudo cp -p compose.yaml compose.yaml.pre-security-20261025
sudo install -o root -g root -m 0644 /tmp/rgo-montra-security.CxzpRzUL/compose.yaml compose.yaml.new
sudo mv -f compose.yaml.new compose.yaml
sudo CATALOG_WORKER_IMAGE="$current_image" COMPOSE_PROFILES= /usr/local/bin/docker compose -f compose.yaml up -d --no-deps --wait --wait-timeout 240 worker
/usr/local/bin/docker inspect --format '{{.Name}} {{.State.Status}} {{if .State.Health}}{{.State.Health.Status}}{{end}}' montra-catalog-worker montra-catalog-updater
```

This preserves the old manifest and the current worker image, reads no private
environment values, and starts only the worker. The commands stop if the updater
is running, the source differs, or the backup name already exists. If readiness
fails, preserve the output and recovery manifest for diagnosis before another
attempt. Keep the staged directory until live acceptance is complete.

Local checks, no NAS writes:

```sh
python3 modules/services/montra/nas/test_compose.py -v
python3 tools/nas-security/test_backup_acl.py -v
git diff --check -- modules/services/montra/nas tools/nas-security docs/security-audit-2026-10-25-nas-remediation.md
```
