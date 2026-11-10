#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../policy.sh"
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
state_dir="$fixture/state"
mkdir -p "$state_dir" "$fixture/cache"
log() { :; }
run() { "$@"; }
fixture_available=4
available_gib() { printf '%s\n' "$fixture_available"; }
auto_pressure=1
pressure=0
force=0
pressure_free_gib=8
pressure_recovery_gib=16
pressure_cooldown_seconds=86400
managed_cache_days=30
now=100000
configure_pressure
[ "$pressure" = 1 ]
# A failed eviction must still respect the attempt cooldown.
run() { return 1; }
if prune_managed_cache "$fixture/cache"; then
  echo 'expected eviction failure' >&2
  exit 1
fi
run() { "$@"; }
pressure=0; force=0; now=100001
configure_pressure
[ "$pressure" = 0 ]
# Recovering past the trigger still runs until the recovery target.
pressure=0; force=0; now=200000; fixture_available=12
configure_pressure
[ "$pressure" = 1 ]
fixture_available=16
pressure_target_reached
[ ! -e "$state_dir/cache-cleanup.pressure-active" ]
# Crossing the trigger after recovery remains subject to cooldown.
pressure=0; force=0; fixture_available=4; now=200001
configure_pressure
[ "$pressure" = 0 ]
# Never delete recently used cache files, even under pressure.
touch "$fixture/cache/warm" "$fixture/cache/cold"
touch -t 202001010000 "$fixture/cache/cold"
managed_cache_days=30
pressure=1; fixture_available=4
prune_managed_cache "$fixture/cache"
[ -f "$fixture/cache/warm" ]
[ ! -e "$fixture/cache/cold" ]
# Recovery stops eviction even when stale cache candidates remain.
touch "$fixture/cache/cold"
touch -t 202001010000 "$fixture/cache/cold"
fixture_available=16
prune_managed_cache "$fixture/cache"
[ -f "$fixture/cache/cold" ]
# Package caches lose whole stale entries, never single files of a live one.
pressure=0
mkdir -p "$fixture/bun/stale@1" "$fixture/bun/live@1"
touch "$fixture/bun/stale@1/index.js" "$fixture/bun/live@1/index.js" "$fixture/bun/live@1/old.js"
touch -t 202001010000 "$fixture/bun/live@1/old.js" "$fixture/bun/stale@1/index.js" "$fixture/bun/stale@1"
prune_cache_entries "$fixture/bun"
[ ! -e "$fixture/bun/stale@1" ]
[ -f "$fixture/bun/live@1/index.js" ]
[ -f "$fixture/bun/live@1/old.js" ]
# Manual-review locations are reported above the threshold and never touched.
report_log="$fixture/report.log"
log() { printf '%s\n' "$*" >>"$report_log"; }
mkdir -p "$fixture/dev/big/tmp" "$fixture/dev/small/tmp"
head -c 4096 /dev/zero >"$fixture/dev/big/tmp/scratch"
report_min_kib=4
report_manual_candidates "agent scratch" "$fixture"/dev/*/tmp "$fixture/missing"
grep -q "in $fixture/dev/big/tmp (agent scratch" "$report_log"
if grep -q "dev/small/tmp" "$report_log"; then exit 1; fi
[ -f "$fixture/dev/big/tmp/scratch" ]
echo 'cache policy tests passed'
