#!/usr/bin/env bash

sketchybar --add item disk right \
  --set disk \
    icon="DISK" \
    icon.color="$FG_MUTED" \
    script="$PLUGIN_DIR/metric.sh disk" \
    update_freq=30 \
    click_script="open /"

sketchybar --add item memory right \
  --set memory \
    icon="RAM" \
    icon.color="$FG_MUTED" \
    script="$PLUGIN_DIR/metric.sh memory" \
    update_freq=5 \
    click_script="open -a 'Activity Monitor'"

sketchybar --add item cpu right \
  --set cpu \
    icon="CPU" \
    icon.color="$FG_MUTED" \
    script="$PLUGIN_DIR/metric.sh cpu" \
    update_freq=3 \
    click_script="open -a 'Activity Monitor'"
