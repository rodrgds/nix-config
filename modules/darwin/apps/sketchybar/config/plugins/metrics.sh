#!/usr/bin/env bash

set -u

# shellcheck source=/dev/null
source "$CONFIG_DIR/theme.sh"

clamp_percent() {
  case "$1" in
    ''|*[!0-9]*) printf '0' ;;
    *)
      if [ "$1" -gt 100 ]; then
        printf '100'
      else
        printf '%s' "$1"
      fi
      ;;
  esac
}

cores="$(sysctl -n hw.logicalcpu 2>/dev/null || printf '1')"
cpu_percent="$(ps -A -o %cpu= | awk -v cores="$cores" '{ total += $1 } END { if (cores < 1) cores = 1; printf "%.0f", total / cores }')"
cpu_percent="$(clamp_percent "$cpu_percent")"

free_percent="$(memory_pressure -Q 2>/dev/null | awk '/System-wide memory free percentage:/ { gsub(/%/, "", $5); print $5 }')"
free_percent="${free_percent:-0}"
memory_percent="$(clamp_percent "$((100 - free_percent))")"
total_bytes="$(sysctl -n hw.memsize 2>/dev/null || printf '0')"
memory_value="$(awk -v total="$total_bytes" -v used="$memory_percent" 'BEGIN { printf "%.1fG", total * used / 100 / 1073741824 }')"

read -r available_kib disk_raw < <(df -k / | awk 'NR == 2 { print $4, $5 }')
disk_percent="$(clamp_percent "${disk_raw%%%}")"
disk_value="$(awk -v available="$available_kib" 'BEGIN { printf "%.0fG", available / 1048576 }')"

memory_accent="$ORANGE"
disk_accent="$YELLOW_BRIGHT"
if [ "$memory_percent" -ge 90 ]; then memory_accent="$RED_BRIGHT"; fi
if [ "$disk_percent" -ge 90 ]; then disk_accent="$RED_BRIGHT"; fi

# Fixed widths match the rendered controls and remove six query/update
# processes from every sample while keeping each utilization line aligned.
sketchybar \
  --set cpu label="${cpu_percent}%" \
  --set cpu.meter slider.percentage="$cpu_percent" slider.highlight_color="$ORANGE_BRIGHT" padding_left=-56 \
  --set memory label="$memory_value" \
  --set memory.meter slider.percentage="$memory_percent" slider.highlight_color="$memory_accent" padding_left=-64 \
  --set disk label="$disk_value" \
  --set disk.meter slider.percentage="$disk_percent" slider.highlight_color="$disk_accent" padding_left=-57

unset -f clamp_percent
