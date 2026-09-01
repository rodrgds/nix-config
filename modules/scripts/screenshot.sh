#!/usr/bin/env bash

set -o pipefail

mode=${1:-region}

if [[ $mode == "region" ]]; then
  selection=$(slurp) || exit $?
  if ! grim -g "$selection" -t ppm - | swappy -f -; then
    notify-send "Screenshot failed" "The selected region could not be opened in Swappy."
    exit 1
  fi
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
