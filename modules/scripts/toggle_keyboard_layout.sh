#!/usr/bin/env bash

if ! hyprctl switchxkblayout all next >/dev/null; then
  notify-send "Keyboard Layout Error" "Hyprland could not switch the keyboard layout."
  exit 1
fi

active_layout=$(hyprctl devices | awk -F': ' '/active keymap:/ { print $2; exit }')
notify-send "Keyboard Layout Changed" "Switched to ${active_layout:-the next configured layout}."
