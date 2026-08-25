#!/usr/bin/env bash

set -u

# shellcheck source=/dev/null
source "$CONFIG_DIR/theme.sh"

title="$(nowplaying-cli get title 2>/dev/null || true)"
artist="$(nowplaying-cli get artist 2>/dev/null || true)"
rate="$(nowplaying-cli get playbackRate 2>/dev/null || true)"
focused="${FOCUSED_WORKSPACE:-$(aerospace list-workspaces --focused 2>/dev/null | head -n 1)}"

if [ -z "$title" ] || [ "$title" = "null" ]; then
  now_playing="Music"
else
  now_playing="$title"
  if [ -n "$artist" ] && [ "$artist" != "null" ]; then
    now_playing="$artist - $title"
  fi
fi

if [ "$rate" != "0" ] && [ "$rate" != "0.0" ] && [ "$rate" != "null" ] && [ -n "$rate" ]; then
  icon=""
else
  icon=""
fi

background="$TRANSPARENT"
icon_color="$FG0"
label_color="$FG0"

if [ "$focused" = "10" ]; then
  background="$ORANGE_BRIGHT"
  icon_color="$BG0"
  label_color="$BG0"
elif [ "${SENDER:-}" = "mouse.entered" ]; then
  background="$BG1"
fi

sketchybar --set "$NAME" \
  icon="$icon" \
  icon.color="$icon_color" \
  label="$now_playing" \
  label.color="$label_color" \
  background.color="$background"
