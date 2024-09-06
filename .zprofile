#!/usr/bin/env bash

if [[ -n "$SSH_CLIENT" ]]; then
	echo "In SSH Session, WM's will not run"
elif [[ "$(tty)" == "/dev/tty3" ]]; then
	rm -r /home/Danuu/.local/share/applications
	cp -r /home/Danuu/.local/share/applications_X /home/Danuu/.local/share/applications
	exec startx
elif [[ "$(tty)" == "/dev/tty2" ]]; then
	rm -r /home/Danuu/.local/share/applications
	cp -r /home/Danuu/.local/share/applications_wayland /home/Danuu/.local/share/applications
	exec sway
elif [[ "$(tty)" == "/dev/tty1" ]]; then
	rm -r /home/Danuu/.local/share/applications
	cp -r /home/Danuu/.local/share/applications_wayland /home/Danuu/.local/share/applications
	exec Hyprland
else
	echo "In $(tty), WM's will not start on launch"
fi
