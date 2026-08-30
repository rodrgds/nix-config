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

echo "Montra deploy payload validation passed"
