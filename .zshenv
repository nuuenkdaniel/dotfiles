# QT exports
export QT_QPA_PLATFORMTHEME="qt5ct"
export QT_QSTYLE_OVERIDE="qt5ct"

export PATH="${PATH}:${HOME}/.local/bin"
export EDITOR="nvim"
export TERM=xterm
export MANPAGER="nvim +Man!"
export BAT_THEME="ansi"

# Maven exports
export MAVEN_OPTS="--enable-native-access=ALL-UNNAMED --sun-misc-unsafe-memory-access=allow"
export M2_HOME=/opt/apache-maven-3.9.10
export PATH=$PATH:$M2_HOME/bin
