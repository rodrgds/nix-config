#!/usr/bin/env bash

mode=${1:-region}

if [[ $mode == "region" ]]; then
  temp_image=$(mktemp --suffix=.png)
  trap 'rm -f "$temp_image"' EXIT

  selection=$(slurp) || exit $?
  if ! grim -g "$selection" "$temp_image"; then
    notify-send "Screenshot failed" "grim could not capture the selected region."
    exit 1
  fi
  if ! wl-copy --type image/png < "$temp_image" >/dev/null 2>&1; then
    notify-send "Screenshot failed" "The image could not be copied to the clipboard."
    exit 1
  fi
  notify-send "Screenshot copied" "The selected region was copied to the clipboard."
elif [[ $mode == "full" ]]; then
  output_file="$HOME/$(date '+%Y-%m-%d-%T')-screenshot.png"

  if ! grim "$output_file"; then
    notify-send "Screenshot failed" "grim could not capture the desktop."
    exit 1
  fi
  if ! wl-copy --type image/png < "$output_file" >/dev/null 2>&1; then
    notify-send "Screenshot saved" "$output_file (clipboard copy failed)"
    exit 1
  fi

  notify-send "Screenshot saved" "$output_file"
else
  printf 'Usage: %s [region|full]\n' "${0##*/}" >&2
  exit 2
fi
