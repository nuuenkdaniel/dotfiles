#!/usr/bin/env bash

if [[ -n "$SSH_CLIENT" ]]; then
	echo "In SSH Session, WM's will not run"
elif [[ "$(tty)" == "/dev/tty3" ]]; then
	exec startx
elif [[ "$(tty)" == "/dev/tty2" ]]; then
	exec sway
elif [[ "$(tty)" == "/dev/tty1" ]]; then
	exec Hyprland
  exec ~/.local/bin/playit_start
else
	echo "In $(tty), WM's will not start on launch"
fi
