#!/usr/bin/env bash

set -u

metric="$1"
meter_name="${NAME}.meter"

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

if [ "$metric" != "cpu" ] && [ "$percent" -ge 90 ] 2>/dev/null; then
  accent="$RED_BRIGHT"
fi

case "$percent" in
  ''|*[!0-9]*) percent=0 ;;
esac
if [ "$percent" -gt 100 ]; then
  percent=100
fi

sketchybar --set "$NAME" \
  label="$value" \
  label.color="$FG0" \
  background.border_width=0

item_width="$(sketchybar --query "$NAME" 2>/dev/null | awk '/"size":/ { width=$3; gsub(/[^0-9.]/, "", width); printf "%.0f", width; exit }')"
item_width="${item_width:-1}"

# The zero-space slider occupies the same bounds as the text item, preserving
# SketchyBar's native two-color icon/label rendering while adding the same
# bottom-aligned utilization line as Quickshell.
sketchybar --set "$meter_name" \
  slider.width="$item_width" \
  slider.percentage="$percent" \
  slider.highlight_color="$accent" \
  padding_left="-$item_width"
