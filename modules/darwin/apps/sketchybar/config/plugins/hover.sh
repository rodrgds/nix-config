#!/usr/bin/env bash

# shellcheck source=/dev/null
source "$CONFIG_DIR/theme.sh"

case "${SENDER:-}" in
  mouse.entered)
    sketchybar --set "$NAME" background.color="$BG2" background.drawing=on
    ;;
  mouse.exited)
    sketchybar --set "$NAME" background.color="$TRANSPARENT"
    ;;
esac
