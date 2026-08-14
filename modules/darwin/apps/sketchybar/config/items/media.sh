#!/usr/bin/env bash

sketchybar --add item media left \
  --set media \
    icon="" \
    label="Music" \
    label.max_chars=42 \
    scroll_texts=off \
    click_script="$PLUGIN_DIR/media_click.sh" \
    script="$PLUGIN_DIR/media.sh" \
    update_freq=3 \
  --subscribe media \
    aerospace_workspace_change media_change mouse.entered mouse.exited
