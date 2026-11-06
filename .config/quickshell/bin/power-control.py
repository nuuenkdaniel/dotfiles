#!/usr/bin/python3 -I
"""Privileged helper. Install root-owned; accepts only fixed hardware operations."""
import json
import os
import pwd
from pathlib import Path
import re
import sys

BATTERY = Path('/sys/class/power_supply/BAT0')
CPU = Path('/sys/devices/system/cpu/intel_pstate')
INSTALL_DIR = Path('/var/lib/quickshell-power')
INSTALL_RECORD = INSTALL_DIR / 'install.json'
INSTALLED_HELPER = Path('/usr/local/libexec/quickshell-power-control')
BOOST_FILES = [Path('/usr/local/libexec/quickshell-boost-control'),
               Path('/usr/share/polkit-1/actions/org.local.quickshell.power.boost.policy'),
               Path('/etc/polkit-1/rules.d/49-quickshell-boost.rules')]


def integer(value, minimum, maximum):
    if not re.fullmatch(r'[0-9]+', str(value)):
        raise ValueError('Expected a whole number')
    result = int(value)
    if not minimum <= result <= maximum:
        raise ValueError(f'Value must be between {minimum} and {maximum}')
    return result


def write_checked(path, value):
    path.write_text(str(value) + '\n')
    if path.read_text().strip() != str(value):
        raise RuntimeError(f'{path.name} did not accept the requested value')


def set_cpu(boost, limit):
    boost = integer(boost, 0, 1)
    limit = integer(limit, 20, 100)
    minimum = int((CPU / 'min_perf_pct').read_text())
    if limit < minimum:
        raise ValueError(f'Performance limit must be at least {minimum}%')
    paths = [CPU / 'no_turbo', CPU / 'max_perf_pct']
    before = [p.read_text().strip() for p in paths]
    try:
        write_checked(paths[0], 1 - boost)
        write_checked(paths[1], limit)
    except Exception:
        for path, value in zip(paths, before):
            path.write_text(value + '\n')
        raise


def set_charging(mode, start, stop, restore_thresholds=False):
    modes = (BATTERY / 'charge_types').read_text()
    supported = [m.strip('[]') for m in modes.split()]
    if mode not in supported:
        raise ValueError('Unsupported charging mode')
    start = integer(start, 50, 95)
    stop = integer(stop, 55, 100)
    if stop - start < 5:
        raise ValueError('Stop threshold must be at least 5% above start')
    mode_path = BATTERY / 'charge_types'
    start_path = BATTERY / 'charge_control_start_threshold'
    stop_path = BATTERY / 'charge_control_end_threshold'
    old_mode = re.search(r'\[([^]]+)\]', modes).group(1)
    old_start = start_path.read_text().strip()
    old_stop = stop_path.read_text().strip()
    try:
        if mode == 'Custom' or restore_thresholds:
            # Widen the interval first to avoid invalid intermediate thresholds.
            write_checked(start_path, 50)
            write_checked(stop_path, stop)
            write_checked(start_path, start)
        mode_path.write_text(mode + '\n')
        if f'[{mode}]' not in mode_path.read_text():
            raise RuntimeError('Firmware did not accept the charging mode')
    except Exception as error:
        try:
            start_path.write_text('50\n')
            stop_path.write_text(old_stop + '\n')
            start_path.write_text(old_start + '\n')
            mode_path.write_text(old_mode + '\n')
        except OSError as rollback_error:
            raise RuntimeError(f'{error}; restore also failed: {rollback_error}') from error
        raise


def snapshot(package_present, service_enabled, service_active, previous_profile):
    if previous_profile not in ('unknown', 'balanced', 'power-saver', 'performance'):
        raise ValueError('Invalid previous profile')
    flags = [bool(integer(value, 0, 1)) for value in (package_present, service_enabled, service_active)]
    if INSTALL_RECORD.exists():
        return  # Never overwrite the original baseline when setup is rerun.
    if INSTALL_DIR.is_symlink():
        raise RuntimeError('Installation state directory must not be a symlink')
    INSTALL_DIR.mkdir(mode=0o700, exist_ok=True)
    INSTALL_DIR.chmod(0o700)
    modes = (BATTERY / 'charge_types').read_text()
    policies = []
    for policy in sorted(Path('/sys/devices/system/cpu/cpufreq').glob('policy[0-9]*')):
        values = {}
        for name in ('scaling_governor', 'energy_performance_preference'):
            path = policy / name
            if path.exists():
                values[name] = path.read_text().strip()
        policies.append({'name': policy.name, 'values': values})
    platform = Path('/sys/firmware/acpi/platform_profile')
    record = {
        'version': 1, 'packagePresent': flags[0], 'serviceEnabled': flags[1], 'serviceActive': flags[2],
        'profile': previous_profile,
        'cpu': {'boost': int((CPU / 'no_turbo').read_text()) == 0,
                'limit': int((CPU / 'max_perf_pct').read_text())},
        'charging': {'mode': re.search(r'\[([^]]+)\]', modes).group(1),
                     'start': int((BATTERY / 'charge_control_start_threshold').read_text()),
                     'stop': int((BATTERY / 'charge_control_end_threshold').read_text())},
        'policies': policies, 'platform': platform.read_text().strip() if platform.exists() else None,
    }
    with INSTALL_RECORD.open('x') as file:
        os.chmod(INSTALL_RECORD, 0o600)
        json.dump(record, file, indent=2)


def installation():
    if not INSTALL_RECORD.is_file():
        raise RuntimeError('No original installation baseline exists. Refusing to guess original hardware settings.')
    record = json.loads(INSTALL_RECORD.read_text())
    if record.get('version') != 1:
        raise ValueError('Unsupported installation record')
    return record


def restore_baseline():
    record = installation()
    saved = record['charging']
    set_charging(saved['mode'], saved['start'], saved['stop'], restore_thresholds=True)
    set_cpu(int(record['cpu']['boost']), record['cpu']['limit'])
    if record.get('platform'):
        platform = Path('/sys/firmware/acpi/platform_profile')
        choices = Path('/sys/firmware/acpi/platform_profile_choices').read_text().split()
        if record['platform'] not in choices:
            raise RuntimeError('Original firmware profile is no longer supported')
        write_checked(platform, record['platform'])
    for policy in record['policies']:
        if not re.fullmatch(r'policy[0-9]+', policy['name']):
            raise ValueError('Invalid policy in installation record')
        path = Path('/sys/devices/system/cpu/cpufreq') / policy['name']
        if not path.exists():
            continue
        for key in ('scaling_governor', 'energy_performance_preference'):
            if key in policy['values']:
                write_checked(path / key, policy['values'][key])


def register_boost_permission(user):
    pwd.getpwnam(user)  # Reject unknown accounts; no shell/JS interpolation here.
    record = installation()
    if not record.get('boostPermissionManaged') and any(path.exists() for path in BOOST_FILES):
        raise RuntimeError('Boost permission files already exist outside this installation; refusing to overwrite them')
    record['boostPermissionManaged'] = True
    record['boostUser'] = user
    temporary = INSTALL_RECORD.with_suffix('.tmp')
    temporary.write_text(json.dumps(record, indent=2) + '\n')
    temporary.chmod(0o600)
    temporary.replace(INSTALL_RECORD)


def remove_installation():
    record = installation()  # Require a known, owned installation.
    if Path(__file__).resolve() != INSTALLED_HELPER:
        raise RuntimeError('Cleanup must be invoked using the installed helper')
    if set(INSTALL_DIR.iterdir()) != {INSTALL_RECORD}:
        raise RuntimeError('Unexpected files in installation state directory; preserving the recovery record')
    if record.get('boostPermissionManaged'):
        for path in reversed(BOOST_FILES):
            path.unlink(missing_ok=True)
    INSTALL_RECORD.unlink()
    INSTALL_DIR.rmdir()  # Never recursively delete unknown files.
    INSTALLED_HELPER.unlink()


def main():
    if os.geteuid() != 0:
        raise PermissionError('Administrator authorization is required')
    args = sys.argv[1:]
    if len(args) == 3 and args[0] == 'cpu':
        set_cpu(*args[1:])
    elif len(args) == 4 and args[0] == 'charging':
        set_charging(*args[1:])
    elif len(args) == 5 and args[0] == 'register-installation':
        snapshot(*args[1:])
    elif args == ['installation-info']:
        print(json.dumps(installation()))
        return
    elif args == ['restore-baseline']:
        restore_baseline()
    elif len(args) == 2 and args[0] == 'register-boost-permission':
        register_boost_permission(args[1])
    elif args == ['remove-installation']:
        remove_installation()
    else:
        raise ValueError('Allowed operations: cpu BOOST LIMIT; charging MODE START STOP')
    print(json.dumps({'ok': True}))


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
