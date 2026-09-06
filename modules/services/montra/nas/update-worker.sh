#!/bin/sh
set -eu

# CI promotes latest only after verification and scanning. The worker's source
# definition checks tolerate the short interval before the API deploy completes.
update_worker() {
  previous=$(docker inspect --format '{{.Image}}' montra-catalog-worker)
  docker compose pull worker || return 1
  candidate=$(docker image inspect --format '{{.Id}}' ghcr.io/rodrgds/montra-catalog-worker:latest)
  [ "$previous" != "$candidate" ] || return 0
  if docker compose up -d --no-deps --wait --wait-timeout 240 worker; then
    echo "Catalog worker updated to $candidate"
  else
    echo "Catalog worker failed readiness; restoring $previous" >&2
    CATALOG_WORKER_IMAGE="$previous" docker compose up -d --no-deps --wait --wait-timeout 240 worker
    return 1
  fi
}

trap 'exit 0' TERM INT
while :; do
  update_worker || echo 'Catalog worker update failed; retrying in ten minutes' >&2
  sleep 600 &
  wait $! || exit 0
done
