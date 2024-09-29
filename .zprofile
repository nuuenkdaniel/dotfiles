#!/usr/bin/env bash

if [[ -n "$SSH_CLIENT" ]]; then
	echo "In SSH Session, WM's will not run"
else
  openrgb --profile "Normal"
  if [[ "$(tty)" == "/dev/tty3" ]]; then
	  exec startx
  elif [[ "$(tty)" == "/dev/tty2" ]]; then
    WLR_BACKENDS=headless,libinput sway
  elif [[ "$(tty)" == "/dev/tty1" ]]; then
	  exec pkill sunshine & pkill sway & Hyprland
  else
	  echo "In $(tty), WM's will not start on launch"
  fi
fi
