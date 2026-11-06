#!/usr/bin/python3
"""Read-only UI diagnostics. Never collect passwords, serial numbers or full configs."""
import json
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys


def command(args, timeout=5):
    try:
        result = subprocess.run(args, capture_output=True, text=True, timeout=timeout)
        return result.stdout.strip() if result.returncode == 0 else ''
    except (OSError, subprocess.TimeoutExpired):
        return ''


def parse_network(text):
    details = {'ipv4': [], 'ipv6': [], 'dns': []}
    for line in text.splitlines():
        key, separator, value = line.partition(':')
        if not separator:
            continue
        if key == 'GENERAL.DEVICE': details['interface'] = value
        elif key == 'GENERAL.CONNECTION': details['connection'] = value
        elif key == 'GENERAL.STATE': details['state'] = value
        elif key.startswith('IP4.ADDRESS'): details['ipv4'].append(value)
        elif key.startswith('IP6.ADDRESS'): details['ipv6'].append(value)
        elif key.startswith('IP4.DNS'): details['dns'].append(value)
        elif key == 'IP4.GATEWAY': details['gateway'] = value
    return details


def network(interface):
    if not re.fullmatch(r'[A-Za-z0-9_.:-]{1,64}', interface):
        return {'error': 'Invalid network interface'}
    text = command(['nmcli', '-t', '-e', 'no', '-f',
                    'GENERAL.DEVICE,GENERAL.CONNECTION,GENERAL.STATE,IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,IP6.ADDRESS',
                    'device', 'show', interface])
    return parse_network(text) if text else {'error': 'Connection details unavailable (NetworkManager/nmcli)'}


def diagnostics():
    release = {}
    for line in Path('/etc/os-release').read_text().splitlines():
        key, _, value = line.partition('=')
        release[key] = value.strip('"')
    model = Path('/sys/class/dmi/id/product_name')
    services = {}
    for name in ['pipewire', 'wireplumber', 'xdg-desktop-portal', 'xdg-desktop-portal-hyprland']:
        value = command(['systemctl', '--user', 'show', name + '.service', '--property=ActiveState', '--value'])
        services[name] = value or 'unavailable'
    for name in ['upower', 'power-profiles-daemon', 'NetworkManager', 'bluetooth']:
        value = command(['systemctl', 'show', name + '.service', '--property=ActiveState', '--value'])
        services[name] = value or 'unavailable'
    return {
        'os': release.get('PRETTY_NAME', 'Linux'), 'kernel': platform.release(),
        'model': model.read_text().strip() if model.exists() else 'Not reported',
        'quickshell': command(['quickshell', '--version']).split('\n')[0] or 'Unavailable',
        'hyprland': command(['hyprctl', 'version']).split('\n')[0] or 'Unavailable',
        'services': services,
        'batteryFeature': (Path(__file__).resolve().parent / 'uninstall-power.sh').is_file(),
        'tools': {name: bool(shutil.which(name)) for name in ['brightnessctl', 'nmcli', 'notify-send', 'wpctl']},
    }


if __name__ == '__main__':
    try:
        if len(sys.argv) == 3 and sys.argv[1] == 'network':
            result = network(sys.argv[2])
        elif len(sys.argv) == 1:
            result = diagnostics()
        else:
            result = {'error': 'Invalid diagnostics request'}
        print(json.dumps(result))
    except Exception as error:
        print(json.dumps({'error': str(error)}))
