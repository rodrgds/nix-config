#!/usr/bin/env bash

current_layout=$(setxkbmap -query | grep layout | awk '{print $2}')

if [ "$current_layout" == "pt" ]; then
  setxkbmap us
  notify-send "Keyboard Layout Changed" "Switched to English (en) keyboard layout."
else
  setxkbmap pt
  notify-send "Keyboard Layout Changed" "Switched to Portuguese (pt) keyboard layout."
fi
