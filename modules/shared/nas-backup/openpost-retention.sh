#!/bin/sh
# NAS-local scheduler, independent of the VPS and successful backup uploads.
set -u
PATH=/bin:/usr/bin:/usr/syno/bin
export PATH
result=0
for dataset in openpost-db openpost-media; do
    if ! SSH_ORIGINAL_COMMAND="prune $dataset" /usr/bin/python3 -I /usr/local/lib/nas-backup/receiver.py; then
        logger -t openpost-retention "Snapshot expiry failed for $dataset"
        result=1
    fi
done
exit "$result"
