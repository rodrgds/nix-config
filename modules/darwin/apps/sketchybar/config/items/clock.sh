#!/usr/bin/env bash

sketchybar --add item clock right \
  --set clock \
    icon.drawing=off \
    label.padding_left=5 \
    script="$PLUGIN_DIR/clock.sh" \
    update_freq=30
