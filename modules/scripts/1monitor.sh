#!/usr/bin/env bash

if ! hyprctl keyword monitor "DP-1,1920x1080@144,0x0,1" \
  || ! hyprctl keyword monitor "HDMI-A-1,disable"; then
  notify-send "Display layout failed" "Hyprland could not enable the single-monitor layout."
  exit 1
fi
