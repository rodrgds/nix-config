#!/usr/bin/env bash

# SketchyBar spawns plugins outside the rc shell, so theme variables are not
# inherited and must be sourced here.
# shellcheck source=/dev/null
source "$CONFIG_DIR/theme.sh"

if [[ "$(bash "@caffeinateToggle@" status)" == "on" ]]; then
  sketchybar --set caffeinate \
    background.color="$ORANGE_BRIGHT" \
    icon.color="$BG0"
else
  sketchybar --set caffeinate \
    background.color="$TRANSPARENT" \
    icon.color="$FG0"
fi
