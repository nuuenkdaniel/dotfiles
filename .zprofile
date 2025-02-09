#!/usr/bin/env bash
if [[ -n "$SSH_CLIENT" ]]; then
  openrgb --profile "Night" &
  export DESKTOP_SESSION="sway"    
  export XDG_CURRENT_DESKTOP="sway"
  export XDG_SESSION_DESKTOP="sway"
  export XDG_SESSION_TYPE="wayland"
  export WLR_BACKENDS="headless"
	echo "In SSH Session, WM's will not run"
else
  openrgb --profile "Normal" &
  if [[ "$(tty)" == "/dev/tty3" ]]; then
	  exec startx
  elif [[ "$(tty)" == "/dev/tty2" ]]; then
    # openrgb --profile "Night" & WLR_BACKENDS=headless,libinput sway
    exec Hyprland -c .config/hypr/hyprland-sunshine.conf
  elif [[ "$(tty)" == "/dev/tty1" ]]; then
	  exec Hyprland
  else
	  echo "In $(tty), WM's will not start on launch"
  fi
fi
