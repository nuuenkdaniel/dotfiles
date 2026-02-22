#!/usr/bin/env bash
if [[ -n "$SSH_CLIENT" ]]; then
  openrgb --profile "Night" > /dev/null &
  export DESKTOP_SESSION="sway"    
  export XDG_CURRENT_DESKTOP="sway"
  export XDG_SESSION_DESKTOP="sway"
  export XDG_SESSION_TYPE="wayland"
  export WLR_BACKENDS="headless"
	echo "In SSH Session, WM's will not run"
else
  openrgb --profile "Normal" > /dev/null & 
  if [[ "$(tty)" == "/dev/tty2" ]]; then
    exec start-hyprland -c .config/hypr/hyprland-sunshine.conf
  elif [[ "$(tty)" == "/dev/tty1" ]]; then
	  exec start-hyprland
  else
	  echo "In $(tty), WM's will not start on launch"
  fi
fi
