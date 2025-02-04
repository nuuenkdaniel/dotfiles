#!/usr/bin/env bash

echo $(upower -i /org/freedesktop/UPower/devices/battery_hidpp_battery_0 | grep "percentage" | awk '{print $2}')
