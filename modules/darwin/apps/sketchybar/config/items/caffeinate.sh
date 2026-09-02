#!/usr/bin/env bash

sketchybar --add item caffeinate right \
  --set caffeinate \
    icon="" \
    icon.font="$MONO_FONT:Regular:13.0" \
    width="$CONTROL_MIN_WIDTH" \
    label.drawing=off \
    background.color="$TRANSPARENT" \
    script="$PLUGIN_DIR/caffeinate.sh" \
    click_script="$PLUGIN_DIR/caffeinate_click.sh" \
  --subscribe caffeinate system_woke
