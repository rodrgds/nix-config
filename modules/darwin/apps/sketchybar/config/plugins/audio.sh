#!/usr/bin/env bash

set -u

# shellcheck source=/dev/null
source "$CONFIG_DIR/theme.sh"

if [ "${SENDER:-}" = "mouse.scrolled" ]; then
  current="$(osascript -e 'output volume of (get volume settings)')"
  target="$((current + SCROLL_DELTA * 5))"
  if [ "$target" -lt 0 ]; then target=0; fi
  if [ "$target" -gt 100 ]; then target=100; fi
  osascript -e "set volume output volume $target" >/dev/null
fi

volume="${INFO:-$(osascript -e 'output volume of (get volume settings)' 2>/dev/null || printf '0')}"
muted="$(osascript -e 'output muted of (get volume settings)' 2>/dev/null || printf 'false')"

if [ "$muted" = "true" ] || [ "$volume" -eq 0 ] 2>/dev/null; then
  icon=""
elif [ "$volume" -lt 50 ]; then
  icon=""
else
  icon=""
fi

if [ "${SENDER:-}" = "mouse.entered" ]; then
  background="$BG2"
else
  background="$TRANSPARENT"
fi

sketchybar --set "$NAME" \
  icon="$icon" \
  label="${volume}%" \
  background.color="$background"
