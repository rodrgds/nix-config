#!/usr/bin/env bash

# shellcheck source=/dev/null
source "$CONFIG_DIR/theme.sh"

layout="$(macism 2>/dev/null)"

case "$layout" in
  com.apple.keylayout.Portuguese)
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
