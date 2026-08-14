#!/usr/bin/env bash

sketchybar --add item keyboard right \
  --set keyboard \
    icon.drawing=off \
    width="$CONTROL_MIN_WIDTH" \
    label="PT" \
    script="$PLUGIN_DIR/keyboard.sh" \
    update_freq=2 \
    click_script="$PLUGIN_DIR/keyboard_click.sh" \
  --subscribe keyboard mouse.entered mouse.exited
