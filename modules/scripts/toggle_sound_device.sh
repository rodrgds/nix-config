#!/usr/bin/env bash

# run this to see available sinks: pactl list short sinks

headset="alsa_output.usb-Logitech_G522_LIGHTSPEED_-_Wireless_Mode_0000000000000000-00.analog-stereo"
speakers="alsa_output.pci-0000_0b_00.4.analog-stereo"
current_sink=$(pactl get-default-sink)
next_sink=""
next_label=""

if [ "$current_sink" == "$headset" ]; then
  next_sink="$speakers"
  next_label="Speakers"
elif [ "$current_sink" == "$speakers" ]; then
  next_sink="$headset"
  next_label="Headset"
else
  notify-send "Audio Output Error" "Unknown audio output device"
  exit 1
fi

pactl set-default-sink "$next_sink"

# Move existing streams too; changing only the default sink affects new audio
# streams and makes the bar action appear to do nothing for running apps.
while read -r input_id _; do
  [ -n "$input_id" ] && pactl move-sink-input "$input_id" "$next_sink"
done < <(pactl list short sink-inputs)

notify-send "Audio Output Changed" "Switched to $next_label"
