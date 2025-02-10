#!/usr/bin/bash

status=$(bluetoothctl show | grep "PowerState" | awk '{print $2}')

if [[ "$status" == on ]]; then
  echo "󰂯"
else
  echo "󰂲"
fi
