#!/usr/bin/env bash

set -u

# shellcheck source=/dev/null
source "$CONFIG_DIR/theme.sh"

focused="${FOCUSED_WORKSPACE:-$(aerospace list-workspaces --focused 2>/dev/null | head -n 1)}"
visible="$(aerospace list-workspaces --monitor all --visible 2>/dev/null || true)"
window_workspaces="$(aerospace list-windows --all --format '%{workspace}' 2>/dev/null || true)"

args=()
workspace_id=1
while [ "$workspace_id" -le 9 ]; do
  background="$TRANSPARENT"
  icon_color="$FG_MUTED"
  indicator=off
  indicator_color="$TRANSPARENT"
  occupied=off
  occupied_color="$ORANGE_BRIGHT"

  if [ "$focused" = "$workspace_id" ]; then
    background="$ORANGE_BRIGHT"
    icon_color="$BG0"
    indicator=on
    indicator_color="$BG0"
  elif printf '%s\n' "$visible" | grep -Fxq "$workspace_id"; then
    background="$BG1"
    icon_color="$FG0"
    indicator=on
    indicator_color="$ORANGE_BRIGHT"
  fi

  if printf '%s\n' "$window_workspaces" | grep -Fxq "$workspace_id"; then
    occupied=on
    if [ "$focused" = "$workspace_id" ]; then
      occupied_color="$BG0"
    else
      icon_color="$FG0"
    fi
  fi

  args+=(
    --set "space.$workspace_id"
    "background.color=$background"
    "icon.color=$icon_color"
    "icon.background.color=$indicator_color"
    "icon.background.drawing=$indicator"
    "label.color=$occupied_color"
    "label.drawing=$occupied"
  )
  workspace_id=$((workspace_id + 1))
done

sketchybar "${args[@]}"
