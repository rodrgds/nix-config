#!/usr/bin/env bash

# run this to see available sinks: pactl list short sinks

headset="alsa_output.usb-Logitech_G522_LIGHTSPEED_-_Wireless_Mode_0000000000000000-00.analog-stereo"
speakers="alsa_output.pci-0000_0b_00.4.analog-stereo"
current_sink=$(pactl info | grep "Default Sink" | cut -d ' ' -f3)

if [ "$current_sink" == "$headset" ]; then
  pactl set-default-sink "$speakers"
  notify-send "Audio Output Changed" "Switched to Speakers"
elif [ "$current_sink" == "$speakers" ]; then
  pactl set-default-sink "$headset"
  notify-send "Audio Output Changed" "Switched to Headset"
else
  echo "The current default sink is neither $headset nor $speakers."
  notify-send "Audio Output Error" "Unknown audio output device"
fi
