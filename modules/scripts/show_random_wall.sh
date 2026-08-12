#!/usr/bin/env bash

# Hyprland starts awww with the session. Give its socket a moment to appear
# during login before asking it to set the initial wallpaper.
for _attempt in {1..20}; do
  if awww query >/dev/null 2>&1; then
    break
  fi
  sleep 0.1
done

if ! awww query >/dev/null 2>&1; then
  notify-send "Wallpaper unavailable" "awww-daemon did not become ready."
  exit 1
fi

wallpaper=""
IFS= read -r -d '' wallpaper < <(
  find "$HOME/hdd/wallpapers/" -type f ! -name '_*' -print0 | shuf -z -n 1
) || true

if [[ -z $wallpaper ]]; then
  notify-send "Wallpaper unavailable" "No wallpapers were found in ~/hdd/wallpapers."
  exit 1
fi

if ! awww img --transition-type none "$wallpaper"; then
  notify-send "Wallpaper unavailable" "awww could not display the selected wallpaper."
  exit 1
fi
