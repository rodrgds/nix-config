# NAS catalog worker

These files declare the Synology worker in `/volume1/docker/montra-catalog-worker`. Keep its existing private `worker.env` outside Git. It must not override `CATALOG_WORKER_COMMIT`, which belongs to the verified image. The external state volume survives container replacement.

Apply changes by copying `compose.yaml` and `update-worker.sh` to that directory, then run `docker compose up -d`. The updater checks CI-promoted images every ten minutes, updates only this worker, waits for readiness, and restores the previous image if readiness fails. Its Docker socket mount grants container-management access; keep the mounted directory writable only by its owner.

The updater uses a pinned Docker CLI image compatible with the NAS Docker 24 daemon. Refresh that digest deliberately and verify client/server compatibility before applying it. VPS processing settings remain in `../default.nix` and are activated through `rebuild --vps`.
