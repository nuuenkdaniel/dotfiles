#!/usr/bin/python3
"""Interactive, narrowly scoped Battery-feature cleanup. No recursive deletion."""
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
HELPER = Path('/usr/local/libexec/quickshell-power-control')
SYSTEM_STATE_DIR = Path('/var/lib/quickshell-power')
CONFIG = Path(os.environ.get('XDG_CONFIG_HOME', str(Path.home() / '.config'))) / 'quickshell'
STATE = Path(os.environ.get('XDG_STATE_HOME', str(Path.home() / '.local/state'))) / 'quickshell'


def run(args, capture=False):
    result = subprocess.run(args, text=True, stdout=subprocess.PIPE if capture else None)
    if result.returncode:
        raise RuntimeError(f'Command failed; cleanup stopped safely: {args[0]}')
    return result.stdout.strip() if capture else ''


def strip_block(text, name):
    pattern = rf'^[ \t]*// BEGIN {re.escape(name)}\n.*?^[ \t]*// END {re.escape(name)}\n'
    changed, count = re.subn(pattern, '', text, flags=re.M | re.S)
    if count != 1:
        raise RuntimeError(f'Expected one {name} marker in SettingsMenu.qml; refusing to guess an edit')
    return changed


def settings_without_battery(text):
    text = strip_block(text, 'BATTERY AUTHORIZATION')
    text = strip_block(text, 'BATTERY PAGE')
    replacements = {
        'IMPORT': None,
        'PROPERTY': None,
        'FOCUS': '  WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None',
        'HEIGHT': '    height: Math.min(600, root.height - 24)',
        'TABS': '            model: root.baseTabs',
        'ICON': '                text: root.tabIcons[tab.modelData]',
    }
    for marker, replacement in replacements.items():
        pattern = rf'^.*// BATTERY FEATURE {marker}\n'
        text, count = re.subn(pattern, '' if replacement is None else replacement + '\n', text, flags=re.M)
        if count != 1:
            raise RuntimeError(f'Expected one Battery {marker} marker; refusing to guess an edit')
    if 'PowerManagement' in text or 'BatterySettings' in text:
        raise RuntimeError('Other Battery references remain in SettingsMenu.qml; remove them before cleanup')
    return text


def indicator_without_battery(text):
    text = strip_block(text, 'BATTERY INDICATOR STATE')
    text = strip_block(text, 'BATTERY INDICATOR LEAF')
    text, imports = re.subn(r'^.*// BATTERY INDICATOR IMPORT\n', '', text, flags=re.M)
    text, widths = re.subn(r'^.*// BATTERY INDICATOR WIDTH\n', '    implicitWidth: batterySymbol.implicitWidth\n', text, flags=re.M)
    if imports != 1 or widths != 1 or 'root.powerSaving' in text or 'PowerProfiles' in text:
        raise RuntimeError('Battery indicator cleanup markers were modified; refusing to guess an edit')
    return text


def remove_file(path):
    if path.is_file() or path.is_symlink():
        path.unlink()


def main():
    if os.geteuid() == 0:
        raise RuntimeError('Run this as your normal user, not with sudo. Individual system operations request sudo.')
    keep_tab = '--keep-tab' in sys.argv[1:]
    if any(arg not in ('--keep-tab', '--check') for arg in sys.argv[1:]):
        raise ValueError('Options: --keep-tab (keep the UI/source); --check (read-only source preflight)')
    settings_path = ROOT / 'components/SettingsMenu.qml'
    original_settings = settings_path.read_text()
    cleaned_settings = settings_without_battery(original_settings)
    indicator_path = ROOT / 'components/InfoTray.qml'
    original_indicator = indicator_path.read_text()
    cleaned_indicator = indicator_without_battery(original_indicator)
    qmldir_path = ROOT / 'globals/qmldir'
    original_qmldir = qmldir_path.read_text()
    cleaned_qmldir = original_qmldir.replace('singleton PowerManagement 1.0 PowerManagement.qml\n', '')
    if cleaned_qmldir == original_qmldir:
        raise RuntimeError('PowerManagement registration was not found; refusing partial source cleanup')
    if '--check' in sys.argv[1:]:
        print('Battery removal markers and singleton registration verified. No files or settings changed.')
        return

    print('This removes ONLY the Battery power-management feature.')
    print('It first disables its automation and restores tracked brightness/display/effect changes.')
    print('If setup was run, it restores the original CPU/charging settings and service state.')
    print('The power-profiles-daemon package is removed only if our setup installed it.')
    print('Other Quickshell tabs, OSDs, notifications, and Hyprland configuration are kept.')
    print('Battery UI/source will be ' + ('kept.' if keep_tab else 'removed, including these uninstall scripts.'))
    if input('Continue? Type REMOVE: ').strip() != 'REMOVE':
        print('Cancelled. Nothing changed.')
        return

    record = None
    if HELPER.exists():
        # Fails closed for legacy installations without a trustworthy baseline.
        record = json.loads(run(['sudo', str(HELPER), 'installation-info'], capture=True))
    elif SYSTEM_STATE_DIR.exists():
        raise RuntimeError('A system installation record exists but its helper is missing; restore the helper before cleanup')

    result = json.loads(run([sys.executable, str(ROOT / 'bin/power.py'), 'prepare-uninstall'], capture=True))
    if result.get('error'):
        raise RuntimeError('Could not restore temporary settings: ' + result['error'])

    if record:
        profile = record['profile'] if record['profile'] != 'unknown' else 'balanced'
        package_present = subprocess.run(['pacman', '-Q', 'power-profiles-daemon'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0
        if package_present:
            run(['busctl', '--system', 'set-property', 'org.freedesktop.UPower.PowerProfiles', '/org/freedesktop/UPower/PowerProfiles', 'org.freedesktop.UPower.PowerProfiles', 'ActiveProfile', 's', profile])
        if package_present and not record['serviceActive']:
            run(['sudo', 'systemctl', 'stop', 'power-profiles-daemon.service'])
        if package_present and not record['serviceEnabled']:
            run(['sudo', 'systemctl', 'disable', 'power-profiles-daemon.service'])
        # Restore low-level preferences after stopping a daemon we started.
        run(['sudo', str(HELPER), 'restore-baseline'])
        if package_present and not record['packagePresent']:
            run(['sudo', 'pacman', '-R', 'power-profiles-daemon'])
        # Keep baseline/helper if an earlier step failed so cleanup can be retried.
        run(['sudo', str(HELPER), 'remove-installation'])

    if not keep_tab:
        # Check again in case the user edited the menu during authentication.
        if settings_path.read_text() != original_settings or qmldir_path.read_text() != original_qmldir or indicator_path.read_text() != original_indicator:
            raise RuntimeError('Settings source changed during cleanup; rerun to avoid overwriting your edits')
        # Remove the page first; this stops the service when Quickshell reloads.
        settings_path.write_text(cleaned_settings)
        indicator_path.write_text(cleaned_indicator)
        qmldir_path.write_text(cleaned_qmldir)
        time.sleep(2)
        for relative in [
            'components/BatterySettings.qml', 'globals/PowerManagement.qml',
            'bin/power.py', 'bin/power-control.py', 'bin/setup-power.sh',
            'bin/boost-control.py', 'bin/org.local.quickshell.power.boost.policy', 'bin/power-boost.rules.in',
            'tests/test_power.py', 'BATTERY.md', 'bin/uninstall-power.sh', 'bin/uninstall-power.py',
        ]:
            remove_file(ROOT / relative)
        # Remove only caches generated by these Python modules, never an entire cache tree.
        for directory, stems in [('bin/__pycache__', ['power', 'power-control', 'boost-control', 'uninstall-power']),
                                  ('tests/__pycache__', ['test_power'])]:
            cache = ROOT / directory
            for stem in stems:
                for path in cache.glob(stem + '.cpython-*.pyc'):
                    remove_file(path)
            if cache.is_dir() and not any(cache.iterdir()):
                cache.rmdir()
        tests = ROOT / 'tests'
        if tests.is_dir() and not any(tests.iterdir()):
            tests.rmdir()
        remove_file(CONFIG / 'battery-preferences.json')
        remove_file(STATE / 'power-session.json')
        remove_file(STATE / 'power.lock')
    print('Battery cleanup complete. No unrelated packages or Quickshell features were removed.')
    if keep_tab:
        print('The disabled Battery UI/source and reset preferences remain (--keep-tab).')


if __name__ == '__main__':
    try:
        main()
    except (Exception, KeyboardInterrupt) as error:
        print(f'Cleanup stopped: {error}', file=sys.stderr)
        sys.exit(1)
