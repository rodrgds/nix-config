#!/usr/bin/env bash

sketchybar --add item media left \
  --set media \
    icon="" \
    label="Music" \
    label.max_chars=42 \
    scroll_texts=off \
    click_script="$PLUGIN_DIR/media_click.sh" \
    script="$PLUGIN_DIR/media.sh" \
  --subscribe media \
    aerospace_workspace_change media_change system_woke mouse.entered mouse.exited
