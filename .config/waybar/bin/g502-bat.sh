#!/usr/bin/env bash

percentage=$(upower -i /org/freedesktop/UPower/devices/battery_hidpp_battery_0 | grep "percentage" | awk '{print $2}')
name=$(upower -i /org/freedesktop/UPower/devices/battery_hidpp_battery_0 | grep "model" | awk '{print $2}')

echo "{\"text\": \"$percentage\", \"alt\": \"$name\"}"

