#!/usr/bin/env bash

add_metric_meter() {
  local name="$1"
  local accent="$2"
  local click_action="$3"

  sketchybar --add slider "${name}.meter" right 1 \
    --set "${name}.meter" \
      icon.drawing=off \
      label.drawing=off \
      background.drawing=off \
      slider.percentage=0 \
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

add_metric_meter disk "$YELLOW_BRIGHT" "open /"
sketchybar --add item disk right \
  --set disk \
    icon="DISK" \
    icon.color="$FG_MUTED" \
    script="$PLUGIN_DIR/metric.sh disk" \
    update_freq=30 \
    click_script="open /"

add_metric_meter memory "$ORANGE" "open -a 'Activity Monitor'"
sketchybar --add item memory right \
  --set memory \
    icon="RAM" \
    icon.color="$FG_MUTED" \
    script="$PLUGIN_DIR/metric.sh memory" \
    update_freq=5 \
    click_script="open -a 'Activity Monitor'"

add_metric_meter cpu "$ORANGE_BRIGHT" "open -a 'Activity Monitor'"
sketchybar --add item cpu right \
  --set cpu \
    icon="CPU" \
    icon.color="$FG_MUTED" \
    script="$PLUGIN_DIR/metric.sh cpu" \
    update_freq=3 \
    click_script="open -a 'Activity Monitor'"

unset -f add_metric_meter
