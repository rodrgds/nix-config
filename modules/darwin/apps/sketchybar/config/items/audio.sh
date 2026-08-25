#!/usr/bin/env bash

sketchybar --add item audio right \
  --set audio \
    script="$PLUGIN_DIR/audio.sh" \
    click_script="open 'x-apple.systempreferences:com.apple.Sound-Settings.extension'" \
  --subscribe audio volume_change system_woke mouse.scrolled mouse.entered mouse.exited
