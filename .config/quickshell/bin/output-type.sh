#!/usr/bin/env bash

currentDevice=$(pactl get-default-sink)
headphone=$(pactl list short | awk '{print $2}' | grep "^alsa_output\.usb-Logitech_PRO_X.*\.analog-stereo$")
speaker=$(pactl list short | awk '{print $2}' | grep "^alsa_output.pci.*\.analog-stereo\(\.[0-9]\)\?$")

if [[ "$currentDevice" == "$headphone" ]]; then
  echo "headphone"
else
  echo "speaker"
fi
