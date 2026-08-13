#!/usr/bin/env bash

set -u

workspace_id="$1"

# shellcheck source=/dev/null
source "$CONFIG_DIR/theme.sh"

focused="${FOCUSED_WORKSPACE:-$(aerospace list-workspaces --focused 2>/dev/null | head -n 1)}"
window_count="$(aerospace list-windows --workspace "$workspace_id" --count 2>/dev/null || printf '0')"

background="$TRANSPARENT"
icon_color="$FG_MUTED"
label_color="$ORANGE_BRIGHT"

if [ "$focused" = "$workspace_id" ]; then
  background="$ORANGE_BRIGHT"
  icon_color="$BG0"
  label_color="$BG0"
elif [ "${SENDER:-}" = "mouse.entered" ]; then
  background="$BG1"
fi

if [ "$window_count" -gt 0 ] 2>/dev/null; then
  occupied_marker="•"
else
  occupied_marker=""
fi

sketchybar --set "$NAME" \
  background.color="$background" \
  icon.color="$icon_color" \
  label="$occupied_marker" \
  label.color="$label_color" \
  label.font="$PRIMARY_FONT:Regular:8.0" \
  label.padding_left=0 \
  label.padding_right=3
