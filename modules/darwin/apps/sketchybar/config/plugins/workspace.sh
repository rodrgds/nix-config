#!/usr/bin/env bash

set -u

workspace_id="$1"

# shellcheck source=/dev/null
source "$CONFIG_DIR/theme.sh"

focused="${FOCUSED_WORKSPACE:-$(aerospace list-workspaces --focused 2>/dev/null | head -n 1)}"
visible_workspaces="$(aerospace list-workspaces --monitor all --visible 2>/dev/null || true)"
window_count="$(aerospace list-windows --workspace "$workspace_id" --count 2>/dev/null || printf '0')"

background="$TRANSPARENT"
icon_color="$FG_MUTED"
indicator_drawing=off
indicator_color="$TRANSPARENT"
occupied_drawing=off
occupied_color="$ORANGE_BRIGHT"

if [ "$focused" = "$workspace_id" ]; then
  background="$ORANGE_BRIGHT"
  icon_color="$BG0"
  indicator_drawing=on
  indicator_color="$BG0"
elif printf '%s\n' "$visible_workspaces" | grep -Fxq "$workspace_id"; then
  background="$BG1"
  icon_color="$FG0"
  indicator_drawing=on
  indicator_color="$ORANGE_BRIGHT"
elif [ "$window_count" -gt 0 ] 2>/dev/null; then
  icon_color="$FG0"
elif [ "${SENDER:-}" = "mouse.entered" ]; then
  background="$BG1"
fi

if [ "$window_count" -gt 0 ] 2>/dev/null; then
  occupied_drawing=on
  if [ "$focused" = "$workspace_id" ]; then
    occupied_color="$BG0"
  fi
fi

sketchybar --set "$NAME" \
  background.color="$background" \
  icon.color="$icon_color" \
  icon.background.color="$indicator_color" \
  icon.background.drawing="$indicator_drawing" \
  label.color="$occupied_color" \
  label.drawing="$occupied_drawing"
