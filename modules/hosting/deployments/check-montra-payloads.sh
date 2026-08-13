#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
digest="sha256:$(printf 'b%.0s' {1..64})"
revision="$(printf 'a%.0s' {1..40})"

valid=$(jq -cn \
  --arg revision "$revision" \
  --arg digest "$digest" \
  '{repository:"rodrgds/montra",sha:$revision,issued_at:1,delivery_id:"1-1",components:{api:$digest}}')
jq -e -f "$script_dir/montra-payload.jq" <<< "$valid" >/dev/null
jq -e -f "$script_dir/montra-payload-components.jq" <<< '{"api":"'"$digest"'"}' >/dev/null

expect_rejected() {
  if jq -e -f "$script_dir/montra-payload.jq" <<< "$1" >/dev/null 2>&1; then
    echo "expected payload rejection: $1" >&2
    exit 1
  fi
}

expect_components_rejected() {
  if jq -e -f "$script_dir/montra-payload-components.jq" <<< "$1" >/dev/null 2>&1; then
    echo "expected component map rejection: $1" >&2
    exit 1
  fi
}

expect_rejected '{}'
expect_rejected "$(jq -c '.repository="someone/else"' <<< "$valid")"
expect_rejected "$(jq -c '.sha="main"' <<< "$valid")"
expect_rejected "$(jq -c '.components={}' <<< "$valid")"
expect_rejected "$(jq -c '.components.evil=.components.api | del(.components.api)' <<< "$valid")"
expect_rejected "$(jq -c '.extra=true' <<< "$valid")"
expect_rejected "$(jq -c '.issued_at=1.5' <<< "$valid")"
expect_rejected "$(jq -c '.delivery_id="bad/id"' <<< "$valid")"
expect_rejected "$(jq -c '.components.api="sha256:ABC"' <<< "$valid")"

expect_components_rejected '{}'
expect_components_rejected '{"evil":"'"$digest"'"}'
expect_components_rejected '{"api":"sha256:ABC"}'

delivery_root="$(mktemp -d)"
trap 'rm -rf "$delivery_root"' EXIT
validator="$script_dir/validate-montra-delivery.sh"
bash "$validator" "$valid" 1 "$delivery_root" "$script_dir/montra-payload.jq"
test -f "$delivery_root/1-1/payload.json"
if bash "$validator" "$valid" 1 "$delivery_root" "$script_dir/montra-payload.jq" >/dev/null 2>&1; then
  echo "expected replayed delivery rejection" >&2
  exit 1
fi
stale="$(jq -c '.delivery_id="stale" | .issued_at=699' <<< "$valid")"
future="$(jq -c '.delivery_id="future" | .issued_at=1061' <<< "$valid")"
boundary="$(jq -c '.delivery_id="boundary" | .issued_at=700' <<< "$valid")"
if bash "$validator" "$stale" 1000 "$delivery_root" "$script_dir/montra-payload.jq" >/dev/null 2>&1; then
  echo "expected stale delivery rejection" >&2
  exit 1
fi
if bash "$validator" "$future" 1000 "$delivery_root" "$script_dir/montra-payload.jq" >/dev/null 2>&1; then
  echo "expected future delivery rejection" >&2
  exit 1
fi
bash "$validator" "$boundary" 1000 "$delivery_root" "$script_dir/montra-payload.jq"

echo "Montra deploy payload validation passed"
