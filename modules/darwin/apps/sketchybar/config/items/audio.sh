#!/usr/bin/env bash

sketchybar --add item audio right \
  --set audio \
    script="$PLUGIN_DIR/audio.sh" \
    update_freq=5 \
    click_script="open 'x-apple.systempreferences:com.apple.Sound-Settings.extension'" \
  --subscribe audio volume_change mouse.scrolled mouse.entered mouse.exited
