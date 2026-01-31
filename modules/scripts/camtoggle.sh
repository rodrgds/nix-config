#!/usr/bin/env bash

pkill -f /dev/video || mpv --osc=no \
  --demuxer-lavf-format=video4linux2 \
  --demuxer-lavf-o-set=input_format=mjpeg \
  --geometry=-0-0 \
  --autofit=21% \
  --vf=crop=in_h:in_h \
  --profile=low-latency \
  --untimed \
  --script="$HOME/.config/mpv/scripts/camtoggle-aspect.lua" \
  /dev/video0
