#!/usr/bin/env bash

add_metric_meter() {
  local name="$1"
  local accent="$2"
  local width="$3"
  local click_action="$4"

  sketchybar --add slider "${name}.meter" right 1 \
    --set "${name}.meter" \
      icon.drawing=off \
      label.drawing=off \
      background.drawing=off \
      slider.percentage=0 \
      slider.width="$width" \
      slider.highlight_color="$accent" \
      slider.knob.drawing=off \
      slider.background.drawing=on \
      slider.background.color="$TRANSPARENT" \
      slider.background.height="$INDICATOR_HEIGHT" \
      slider.background.corner_radius=0 \
      slider.background.y_offset=-10 \
      padding_left=-1 \
      padding_right=0 \
      click_script="$click_action" \
      updates=off
}

add_metric_meter disk "$YELLOW_BRIGHT" 57 "open /"
sketchybar --add item disk right \
  --set disk \
    icon="DISK" \
    icon.font="$UI_FONT:Regular:12.0" \
    icon.color="$FG_MUTED" \
    width=57 \
    click_script="open /"

add_metric_meter memory "$ORANGE" 64 "open -a 'Activity Monitor'"
sketchybar --add item memory right \
  --set memory \
    icon="RAM" \
    icon.font="$UI_FONT:Regular:12.0" \
    icon.color="$FG_MUTED" \
    width=64 \
    click_script="open -a 'Activity Monitor'"

add_metric_meter cpu "$ORANGE_BRIGHT" 56 "open -a 'Activity Monitor'"
sketchybar --add item cpu right \
  --set cpu \
    icon="CPU" \
    icon.font="$UI_FONT:Regular:12.0" \
    icon.color="$FG_MUTED" \
    width=56 \
    click_script="open -a 'Activity Monitor'"

sketchybar --add item metrics.observer right \
  --set metrics.observer \
    drawing=off \
    updates=on \
    script="$PLUGIN_DIR/metrics.sh" \
    update_freq=5 \
  --subscribe metrics.observer system_woke

unset -f add_metric_meter
