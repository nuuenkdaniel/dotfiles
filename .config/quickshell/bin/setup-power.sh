#!/bin/sh
# Run explicitly in a terminal: bash ~/.config/quickshell/bin/setup-power.sh
set -eu
source_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
helper=/usr/local/libexec/quickshell-power-control
if test "$(id -u)" = 0; then
    printf '%s\n' 'Run setup as your normal user, without sudo; individual operations request authorization.' >&2
    exit 1
fi
printf '%s\n' 'Installing the power-profile service and a root-owned hardware helper.'
printf '%s\n' 'No charging thresholds or CPU limits will be changed by this setup.'
for service in tlp tuned auto-cpufreq; do
    if systemctl is-active --quiet "$service.service" || systemctl is-enabled --quiet "$service.service" 2>/dev/null; then
        printf '%s\n' "Stop and disable the existing $service policy manager before continuing." >&2
        exit 1
    fi
done
if test -e "$helper" && ! sudo test -f /var/lib/quickshell-power/install.json; then
    printf '%s\n' 'A helper without an original baseline already exists. Refusing to overwrite it.' >&2
    exit 1
fi
package_present=0
service_enabled=0
service_active=0
previous_profile=unknown
if pacman -Q power-profiles-daemon >/dev/null 2>&1; then package_present=1; fi
if systemctl is-enabled --quiet power-profiles-daemon.service 2>/dev/null; then service_enabled=1; fi
if systemctl is-active --quiet power-profiles-daemon.service; then service_active=1; fi
if test "$service_active" = 1; then
    previous_profile=$(busctl --system get-property org.freedesktop.UPower.PowerProfiles /org/freedesktop/UPower/PowerProfiles org.freedesktop.UPower.PowerProfiles ActiveProfile | sed -n 's/^s "\([a-z-]*\)"$/\1/p')
fi
sudo install -d -o root -g root -m 0755 /usr/local/libexec
sudo install -o root -g root -m 0755 "$source_dir/power-control.py" "$helper"
# Capture hardware settings and package ownership before starting the daemon.
sudo "$helper" register-installation "$package_present" "$service_enabled" "$service_active" "$previous_profile"
sudo "$helper" register-boost-permission "$(id -un)"
rules_file=$(mktemp "${XDG_RUNTIME_DIR:-/tmp/opencode}/quickshell-boost-rules.XXXXXX")
trap 'rm -f -- "$rules_file"' EXIT HUP INT TERM
python3 - "$source_dir/power-boost.rules.in" "$(id -un)" > "$rules_file" <<'PY'
import json
from pathlib import Path
import sys
print(Path(sys.argv[1]).read_text().replace('__USER_JSON__', json.dumps(sys.argv[2])))
PY
sudo install -o root -g root -m 0755 "$source_dir/boost-control.py" /usr/local/libexec/quickshell-boost-control
if ! test -d /usr/share/polkit-1/actions; then sudo install -d -o root -g root -m 0755 /usr/share/polkit-1/actions; fi
if ! test -d /etc/polkit-1/rules.d; then sudo install -d -o root -g root -m 0750 /etc/polkit-1/rules.d; fi
sudo install -o root -g root -m 0644 "$source_dir/org.local.quickshell.power.boost.policy" /usr/share/polkit-1/actions/org.local.quickshell.power.boost.policy
sudo install -o root -g root -m 0644 "$rules_file" /etc/polkit-1/rules.d/49-quickshell-boost.rules
sudo pacman -S --needed power-profiles-daemon
sudo systemctl enable --now power-profiles-daemon.service
printf '%s\n' 'Setup complete. Reopen the Battery tab; no shell restart is required.'
printf '%s\n' 'Boost toggles are passwordless only for this user in an active local session. CPU limits and charging still require authorization.'
