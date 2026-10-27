# OpenPost Radio on the NAS

This directory owns `/volume1/docker/openpost-radio` on `kraktoos@rgo-nas`.
The NAS has Intel J4025 graphics with VAAPI H.264 encoding; the VPS has only
virtio graphics. Keep the live renderer and hardware encoder on the NAS so
radio consumes no VPS CPU, RAM, or music-library disk.

The authoritative music library is
`/volume1/homes/kraktoos/openpost-radio-music`. Generate new compositions on a
workstation, then run `scripts/publish-nas-library.sh` in the music project.
The producer copies finished audio before atomically publishing its catalog.
The stream keeps ten planned tracks ahead and refreshes the catalog as it
refills. Local NAS playback reads the originals directly. The HTTP-source
fallback uses a bounded disk cache and two background transfers.

Build `openpost-radio:runtime` using this Dockerfile on the NAS. Copy the
project's `src/`, `assets/`, and `package.json` to `app/`, preserving `state/`.
Copy this compose manifest. DSM's render-device GID is 937; verify it before
moving to another host. No privileged container or Docker socket is needed.
The base images are pinned, and only Node is added to the existing media
runtime. The stream imports no composer/native-audio npm dependencies.

The encrypted credential is `secrets/openpost-radio.env` in this configuration
repository. Decrypt on an authorized workstation with SOPS and stream its
contents over SSH to `credentials.env`, mode 0600. Never copy plaintext into
`app/` or an image layer. The private card used for initial provisioning is
not a durable secret source.

An authorized NAS rollout uses:

```sh
cd /volume1/docker/openpost-radio
/usr/local/bin/docker compose -f compose.yaml up -d --no-deps radio
/usr/local/bin/docker compose -f compose.yaml ps
/usr/local/bin/docker logs --tail 30 openpost-radio
/usr/local/bin/docker stats --no-stream openpost-radio
```

Check `/state/status.json` for advancing encoded seconds/bytes and a full
lookahead queue. Docker health requires a recent frame and successful
encoder progress. Confirm YouTube's ingest separately from public playback;
a valid key can feed an event that still waits for the owner to press Go Live.

The radio owns only this container and these directories. Leave existing
Jellyfin, Montra, NAS backups, and DSM firewall configuration unchanged.
