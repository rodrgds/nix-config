#!/usr/bin/env bash

set -u

metric="$1"

# shellcheck source=/dev/null
source "$CONFIG_DIR/theme.sh"

percent=0
value="—"
accent="$ORANGE_BRIGHT"

case "$metric" in
  cpu)
    cores="$(sysctl -n hw.logicalcpu 2>/dev/null || printf '1')"
    percent="$(ps -A -o %cpu= | awk -v cores="$cores" '{ total += $1 } END { if (cores < 1) cores = 1; printf "%.0f", total / cores }')"
    value="${percent}%"
    ;;
  memory)
    free_percent="$(memory_pressure -Q 2>/dev/null | awk '/System-wide memory free percentage:/ { gsub(/%/, "", $5); print $5 }')"
    free_percent="${free_percent:-0}"
    percent="$((100 - free_percent))"
    total_bytes="$(sysctl -n hw.memsize 2>/dev/null || printf '0')"
    used_gib="$(awk -v total="$total_bytes" -v used="$percent" 'BEGIN { printf "%.1f", total * used / 100 / 1073741824 }')"
    value="${used_gib}G"
    accent="$ORANGE"
    ;;
  disk)
    read -r _ _ available_kib percent_raw < <(df -k / | awk 'NR == 2 { print $2, $3, $4, $5 }')
    percent="${percent_raw%%%}"
    free_gib="$(awk -v available="$available_kib" 'BEGIN { printf "%.0f", available / 1048576 }')"
    value="${free_gib}G"
    accent="$YELLOW_BRIGHT"
    ;;
esac

border_width=0
if [ "$percent" -ge 90 ] 2>/dev/null; then
  accent="$RED_BRIGHT"
  border_width=1
fi

sketchybar --set "$NAME" \
  label="$value" \
  label.color="$FG0" \
  background.border_width="$border_width" \
  background.border_color="$accent"
