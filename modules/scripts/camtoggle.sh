#!/usr/bin/env bash

pkill -f /dev/video || mpv --osc=no \
  --title="Camera Preview" \
  --demuxer-lavf-format=video4linux2 \
  --demuxer-lavf-o-set=input_format=mjpeg \
  --vf=crop=in_h:in_h \
  --profile=low-latency \
  --untimed \
  --script="$HOME/.config/mpv/scripts/camtoggle-aspect.lua" \
  /dev/video0
