# NAS catalog worker

These files declare the Synology worker in `/volume1/docker/montra-catalog-worker`. Keep its existing private `worker.env` outside Git. It must not override `CATALOG_WORKER_COMMIT`, which belongs to the verified image. The external state volume survives container replacement.

Apply changes only during an authorized NAS rollout. Copy `compose.yaml` and
`update-worker.sh` to that directory and recreate only the worker, retaining its
current exact image during a hardening-only rollout:

```sh
cd /volume1/docker/montra-catalog-worker
current_image=$(/usr/local/bin/docker inspect --format '{{.Image}}' montra-catalog-worker)
sudo CATALOG_WORKER_IMAGE="$current_image" COMPOSE_PROFILES= /usr/local/bin/docker compose -f compose.yaml up -d --no-deps --wait --wait-timeout 240 worker
```

The updater is behind the `automatic-updates` Compose profile. Default Compose
commands without profile opt-in do not select it. `COMPOSE_PROFILES`, including
a setting in `.env`, can also opt in. The worker-only command above clears it,
names the owned manifest explicitly and uses `sudo` because the NAS project
contains a root-private `.env`. A profile does not stop an already running updater,
change an existing container's restart policy, or prevent an explicit `updater`
target from starting it. The October 2026 audit found it stopped; preserve that
state during worker maintenance. Before recreating the worker, confirm
`docker inspect --format '{{.State.Running}}' montra-catalog-updater` is `false`.
If it is running, resolve its enablement with the rollout owner first.

Only after a separate decision to resume automatic updates, start it with
`sudo /usr/local/bin/docker compose -f compose.yaml --profile automatic-updates up -d --no-deps updater`.
It checks CI-promoted images every ten minutes, waits for worker readiness,
and restores the previous image if readiness fails. It mounts private Docker
registry credentials read-only. Its socket grants host administration authority;
keep the Compose directory writable only by its administrator.

The updater uses a pinned Docker CLI image compatible with the NAS Docker 24 daemon. The NAS kernel does not support Docker CPU quotas; retain the memory limit and omit `cpus`. Refresh that digest deliberately and verify client/server compatibility before applying it. VPS processing settings remain in `../default.nix` and are activated through `rebuild --vps`.

The worker explicitly runs as the image's `bun` user, drops Linux capabilities,
and cannot gain privileges through setuid binaries. The updater also drops
capabilities and uses a read-only container filesystem with a bounded temporary
directory. These settings do not confine Docker API authority: the updater's
socket still permits control of the NAS daemon. Treat the updater and the
mounted registry credential as host administration, and keep agent workloads
away from that socket and credential. A read-only socket mount would not make
Docker API calls read-only.

Before an authorized rollout, validate Compose using a temporary, nonsecret
`worker.env` fixture. After applying it, verify worker readiness and one ordinary
scraping task, including browser launch, state writes and clean shutdown. Verify
the updater can pull and recreate only the intended worker in its normal flow,
without printing environment files or registry credentials. Source validation
alone does not establish NAS runtime compatibility. The October 2026 audit
found the worker running but the updater stopped, so enablement is an explicit
rollout decision rather than an assumed existing background service.

Run `python3 modules/services/montra/nas/test_compose.py -v` from the repository
root to verify default and opt-in service selection using only a temporary
nonsecret environment fixture and no Docker daemon. NAS administrative
procedures are in [tools/nas-security](../../../../tools/nas-security/README.md).
