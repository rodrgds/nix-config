#!/usr/bin/env bash

sketchybar --add item keyboard right \
  --set keyboard \
    icon.drawing=off \
    width="$CONTROL_MIN_WIDTH" \
    label="PT" \
    script="$PLUGIN_DIR/keyboard.sh" \
    update_freq=10 \
    click_script="$PLUGIN_DIR/keyboard_click.sh" \
  --subscribe keyboard keyboard_layout_change system_woke mouse.entered mouse.exited
