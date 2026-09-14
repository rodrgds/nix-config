set -euo pipefail

# Podman health checks use transient systemd units keyed by container ID.
# Container removal can leave a timer loaded, which then fails every interval.
declare -A live_container_ids=()
live_containers="$(podman container list --all --no-trunc --format '{{.ID}}')"
while read -r container_id; do
  [ -n "$container_id" ] || continue
  [[ "$container_id" =~ ^[0-9a-f]{64}$ ]] || {
    echo "podman-health-unit-cleanup: invalid container ID: $container_id" >&2
    exit 1
  }
  live_container_ids["$container_id"]=1
done <<< "$live_containers"

declare -A orphaned_container_ids=()
loaded_units="$(systemctl list-units --all --plain --no-legend)"
while read -r unit _; do
  if [[ "$unit" =~ ^([0-9a-f]{64})-.*\.(timer|service)$ ]]; then
    container_id="${BASH_REMATCH[1]}"
    if [[ -z "${live_container_ids[$container_id]+present}" ]]; then
      orphaned_container_ids["$container_id"]=1
    fi
  fi
done <<< "$loaded_units"

for container_id in "${!orphaned_container_ids[@]}"; do
  echo "podman-health-unit-cleanup: removing units for $container_id"
  for unit_type in timer service; do
    matching_units="$(
      systemctl list-units --all --plain --no-legend \
        "$container_id-*.$unit_type"
    )"
    while read -r unit _; do
      [ -n "$unit" ] || continue
      systemctl stop "$unit" || true
      if [ "$unit_type" = service ]; then
        systemctl reset-failed "$unit" || true
      fi
    done <<< "$matching_units"
  done
done
