export QT_QPA_PLATFORMTHEME="qt5ct"
export QT_QSTYLE_OVERIDE="qt5ct"
export PATH="${PATH}:${HOME}/.local/bin"
export EDITOR="nvim"

if [[ "$WAYLAND_DISPLAY" ]]; then
  export WAYLANDAPP="--enable-features=UseOzonePlatform --ozone-platform=wayland"
fi
