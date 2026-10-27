# OpenPost Radio NAS storage

The live sender runs on `rgo-vps`. The NAS stores audio and pre-encoded
programmes only. Do not start a radio renderer or encoder on the NAS.
The retired `openpost-radio` container must remain stopped with restart=no.

The authoritative library is
`/volume1/homes/kraktoos/openpost-radio-music`. Generate compositions and
prepare programmes on a workstation. Publish finished audio before the
catalog with `scripts/publish-nas-library.sh` in `/Users/rgo/dev/rgo-music`.
`node src/cli/program.js --hours 8 --fps 30` publishes four-minute video
chunks and `programmes/current.json` there.

`library-read.py` is the read-only SSH forced-command receiver at
`/usr/local/lib/openpost-radio/library-read.py`, root-owned mode 0755.
The dedicated public key in `/etc/ssh/authorized_keys/kraktoos` has
`restrict,command="/usr/local/lib/openpost-radio/library-read.py"` options.
It accepts only `read` followed by an allowlisted radio asset path. It
rejects traversal, commands, and paths resolving outside the library.
`provision-library.py` installs only this receiver and appends this key,
using the narrow `/host-lib`, `/keys` and `/input` mounts documented by
its source. Preserve unrelated authorized keys and DSM ACLs.

The VPS module in the parent directory consumes SOPS-encrypted
`secrets/openpost-radio-env` and `secrets/openpost-radio-nas-key` at runtime.
Its known-host file is `/etc/nas-backup/known_hosts`. Keep this identity
separate from the existing backup writer. Verify a manifest read succeeds
and an arbitrary command returns 126 before enabling the relay.

Leave Jellyfin, Montra, NAS backups, and DSM firewall configuration alone.
