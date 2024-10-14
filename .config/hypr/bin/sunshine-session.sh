#!/usr/bin/env bash

if [[ "$SUNSHINE" == "1" ]]; then
  hyprctl output remove DP-1
  hyprctl output remove HDMI-A-1
  hyprctl output create headless headless-1
fi
