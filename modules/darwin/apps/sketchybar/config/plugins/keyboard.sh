#!/usr/bin/env bash

# shellcheck source=/dev/null
source "$CONFIG_DIR/theme.sh"

layout="$(defaults read com.apple.HIToolbox AppleSelectedInputSources 2>/dev/null | awk -F'= ' '/KeyboardLayout Name/ { gsub(/[";]/, "", $2); value=$2 } END { print value }')"

case "$layout" in
  *Portuguese*)
    next_label="EN"
    ;;
  *)
    next_label="PT"
    ;;
esac

if [ "${SENDER:-}" = "mouse.entered" ]; then
  background="$BG2"
else
  background="$TRANSPARENT"
fi

sketchybar --set "$NAME" \
  label="$next_label" \
  background.color="$background"
