#!/usr/bin/env bash
set -euo pipefail

headset="alsa_output.usb-Logitech_G522_LIGHTSPEED_-_Wireless_Mode_0000000000000000-00.analog-stereo"
speakers="alsa_output.pci-0000_0b_00.4.analog-stereo"

sink_name() {
  wpctl inspect "$1" | sed -n 's/^  \* node.name = "\(.*\)"/\1/p'
}

sink_id() {
  wpctl status -n \
    | grep -F ". $1 " \
    | sed -E 's/^[^0-9]*([0-9]+)\..*/\1/'
}

current_sink=$(sink_name @DEFAULT_AUDIO_SINK@)

if [ "$current_sink" = "$headset" ]; then
  next_sink="$speakers"
  next_label="Speakers"
elif [ "$current_sink" = "$speakers" ]; then
  next_sink="$headset"
  next_label="Headset"
else
  notify-send "Audio Output Error" "Unknown audio output device"
  exit 1
fi

next_id=$(sink_id "$next_sink")
if [ -z "$next_id" ]; then
  notify-send "Audio Output Error" "$next_label is unavailable"
  exit 1
fi

wpctl set-default "$next_id"
notify-send "Audio Output Changed" "Switched to $next_label"
