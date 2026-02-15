#!/usr/bin/env bash
# disk-tree.sh - recursively show disk usage tree for a path
# Usage: disk-tree.sh <path> [threshold]
# Example: ./disk-tree.sh / 100M

set -euo pipefail

PATH_TO_SCAN=${1:-/}
THRESH=${2:-100M}   # recurse into dirs >= this size
MAX_DEPTH=${3:-8}

# track visited inodes to avoid cycles (associative array)
declare -A VISITED=()

# convert human to bytes (fallback if numfmt missing)
if command -v numfmt >/dev/null 2>&1; then
  THRESH_BYTES=$(numfmt --from=iec "${THRESH}")
  human() { numfmt --to=iec --suffix=B "$1"; }
else
  # fallback: simple pass-through with B suffix
  THRESH_BYTES=${THRESH}
  human() { [ -z "$1" ] && echo "0B" || echo "${1}B"; }
fi

tree() {
  local path="$1"
  local indent="$2"
  local depth=${3:-0}
  if [ "$depth" -ge "$MAX_DEPTH" ]; then
    return
  fi
  # track visited inodes to avoid cycles
  if command -v stat >/dev/null 2>&1; then
    local key
    key=$(stat -c "%d:%i" "$path" 2>/dev/null || true)
    if [ -n "$key" ]; then
      if [ -z "${VISITED[$key]:-}" ]; then
        VISITED[$key]=1
      else
        return
      fi
    fi
  fi
  # list children sizes in bytes, sorted largest first
  # use -x to stay on same filesystem and avoid virtual filesystems like /proc
  # handle empty globs safely
  tmpf=$(mktemp /tmp/disk_tree.XXXXXX) || tmpf="/tmp/.disk_tree.$$"
  for p in "$path"/*; do
    [ -e "$p" ] || continue
    size=$(du -sbx --apparent-size "$p" 2>/dev/null | awk '{print $1}') || size=0
    printf "%s %s %s\n" "$size" "$p" >> "$tmpf"
  done
  sort -nr "$tmpf" | while read -r size p; do
    printf "%s %10s %s\n" "$indent" "$(human "$size")" "$p"
    if [ -d "$p" ] && [ "$size" -ge "$THRESH_BYTES" ]; then
      tree "$p" "  $indent" $((depth+1))
    fi
  done
  rm -f "$tmpf"
}

# header
echo "Disk tree for: $PATH_TO_SCAN (recursing into dirs >= $THRESH)"
# top-level entry itself
root_size=$(du -sbx --apparent-size "$PATH_TO_SCAN" 2>/dev/null | awk '{print $1}' || true)
root_size=${root_size:-0}
printf "%s %10s %s\n" "" "$(human "$root_size")" "$PATH_TO_SCAN"
tree "$PATH_TO_SCAN" ""
