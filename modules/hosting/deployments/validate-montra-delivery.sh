#!/usr/bin/env bash
set -euo pipefail

[ "$#" -eq 4 ] || {
  echo "usage: validate-montra-delivery PAYLOAD NOW DELIVERY_ROOT PAYLOAD_FILTER" >&2
  exit 64
}

payload="$1"
now="$2"
delivery_root="$3"
payload_filter="$4"

[[ "$now" =~ ^[0-9]{1,10}$ ]] || {
  echo "invalid current timestamp" >&2
  exit 1
}
jq -e -f "$payload_filter" <<< "$payload" >/dev/null || {
  echo "invalid Montra deployment payload" >&2
  exit 1
}

revision="$(jq -er .sha <<< "$payload")"
issued_at="$(jq -er .issued_at <<< "$payload")"
delivery_id="$(jq -er .delivery_id <<< "$payload")"
if [ "$issued_at" -lt "$((now - 300))" ]; then
  echo "Montra delivery is older than five minutes" >&2
  exit 1
fi
if [ "$issued_at" -gt "$((now + 60))" ]; then
  echo "Montra delivery timestamp is too far in the future" >&2
  exit 1
fi
[ -d "$delivery_root" ] || {
  echo "Montra delivery record directory is unavailable" >&2
  exit 1
}

delivery_path="$delivery_root/$delivery_id"
if ! mkdir "$delivery_path" 2>/dev/null; then
  echo "duplicate Montra delivery ID" >&2
  exit 1
fi
umask 0077
printf '%s' "$payload" > "$delivery_path/payload.json"
printf '%s\n' "$issued_at" > "$delivery_path/issued_at"
printf '%s\n' "$revision" > "$delivery_path/revision"
