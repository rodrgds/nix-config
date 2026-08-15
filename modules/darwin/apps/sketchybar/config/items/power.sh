#!/usr/bin/env bash

sketchybar --add item power right \
  --set power \
    icon="⏻" \
    width="$CONTROL_MIN_WIDTH" \
    label.drawing=off \
    background.border_color="$RED_BRIGHT" \
    click_script="@vicinaeLauncher@ 'vicinae://launch/power'" \
    script="$PLUGIN_DIR/hover.sh" \
  --subscribe power mouse.entered mouse.exited
