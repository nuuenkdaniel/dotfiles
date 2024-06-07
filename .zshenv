export QT_QPA_PLATFORMTHEME
export PATH="${PATH}:${HOME}/.local/bin"
if [[ "$WAYLAND_DISPLAY" ]]; then
  export WAYLANDAPP="--enable-features=UseOzonePlatform --ozone-platform=wayland"
fi
