#!/usr/bin/bash

headphones_mac="80:99:E7:1A:63:0D"
power_state=$(bluetoothctl show | grep "PowerState" | awk '{print $2}')

if [[ $power_state == "off" ]]; then
  bluetoothctl power on > /dev/null
  status=$(bluetoothctl connect $headphones_mac | grep "Failed");
  if [[ -n "$status" ]]; then
    bluetoothctl power off > /dev/null
    echo "󰂲"
  else
    echo "󰂯"
  fi
else
  bluetoothctl power off > /dev/null
  echo "󰂲"
fi
