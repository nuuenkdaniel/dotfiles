#!/usr/bin/python3
"""User-session power settings. No shell interpolation or privileged arbitrary writes."""
import fcntl
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time
import uuid

DEFAULTS = {
    'limitBrightness': False, 'brightnessCap': 40,
    'reduceRefresh': False, 'keyboardOff': False, 'reduceEffects': False,
    'autoLow': False, 'lowThreshold': 20, 'autoUnplug': False, 'normalOnAc': False,
    'customBase': 'balanced', 'customCpuEnabled': False, 'customBoost': True, 'customLimit': 100,
    'customSetBrightness': False, 'customBrightness': 40,
    'customSetKeyboard': False, 'customKeyboard': 1,
}
# The standard preset uses 60 Hz; keyboard lighting remains user-controlled.
RECOMMENDED = dict(DEFAULTS, limitBrightness=True, brightnessCap=40, reduceRefresh=True, customCpuEnabled=True, customBoost=False)
CONFIG = Path(os.environ.get('XDG_CONFIG_HOME', str(Path.home() / '.config'))) / 'quickshell' / 'battery-preferences.json'
STATE_DIR = Path(os.environ.get('XDG_STATE_HOME', str(Path.home() / '.local/state'))) / 'quickshell'
STATE_FILE = STATE_DIR / 'power-session.json'
HELPER = Path('/usr/local/libexec/quickshell-power-control')
BOOST_HELPER = Path('/usr/local/libexec/quickshell-boost-control')
BOOST_POLICY = Path('/usr/share/polkit-1/actions/org.local.quickshell.power.boost.policy')
BOOT = Path('/proc/sys/kernel/random/boot_id').read_text().strip()
PROFILE_BUS = ['busctl', '--system']
PROFILE_OBJECT = ['org.freedesktop.UPower.PowerProfiles', '/org/freedesktop/UPower/PowerProfiles', 'org.freedesktop.UPower.PowerProfiles', 'ActiveProfile']
BATTERY = Path('/sys/class/power_supply/BAT0')
CPU = Path('/sys/devices/system/cpu/intel_pstate')


def read(path, default=None):
    try:
        return Path(path).read_text().strip()
    except OSError:
        return default


def number(path):
    value = read(path)
    return int(value) if value is not None else None


def load(path, default):
    try:
        value = json.loads(path.read_text())
        return value if isinstance(value, dict) else default.copy()
    except (OSError, ValueError):
        return default.copy()


def save(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + '.tmp')
    temporary.write_text(json.dumps(value, indent=2) + '\n')
    temporary.chmod(0o600)
    temporary.replace(path)


def command(args, timeout=8):
    result = subprocess.run(args, capture_output=True, text=True, timeout=timeout)
    if result.returncode:
        raise RuntimeError((result.stderr or result.stdout or f'{args[0]} failed').strip())
    return result.stdout.strip()


def profile():
    try:
        result = command(PROFILE_BUS + ['get-property'] + PROFILE_OBJECT)
        return json.loads(result.removeprefix('s '))
    except (OSError, RuntimeError, ValueError, subprocess.TimeoutExpired):
        return None


def profiles():
    try:
        result = json.loads(command(['busctl', '--system', '--json=short', 'get-property'] + PROFILE_OBJECT[:-1] + ['Profiles']))
        return [entry['Profile']['data'] for entry in result['data']]
    except (OSError, RuntimeError, KeyError, TypeError, ValueError, subprocess.TimeoutExpired):
        return ['balanced', 'power-saver'] if profile() else []


def monitor():
    try:
        return next((m for m in json.loads(command(['hyprctl', 'monitors', '-j'])) if m['name'].startswith('eDP')), None)
    except (RuntimeError, ValueError, subprocess.TimeoutExpired):
        return None


def monitor_signature(m):
    return [m['name'], m['width'], m['height'], round(m['refreshRate']), m['x'], m['y'], m['scale'], m.get('transform', 0)]


def set_monitor(m, rate):
    # Lua configuration cannot use the legacy `hyprctl keyword monitor` API.
    # Leave VRR policy unspecified: the runtime `vrr` boolean is only its current
    # state, not the configured always/fullscreen policy.
    depth = 10 if '2101010' in m.get('currentFormat', '') else 8
    fields = {
        'output': m['name'], 'mode': f"{m['width']}x{m['height']}@{rate}",
        'position': f"{m['x']}x{m['y']}", 'scale': m['scale'],
        'transform': m.get('transform', 0), 'bitdepth': depth,
        'cm': m.get('colorManagementPreset', 'srgb'),
    }
    lua = 'hl.monitor({ ' + ', '.join(key + ' = ' + json.dumps(value) for key, value in fields.items()) + ' })'
    output = command(['hyprctl', 'eval', lua])
    if output.lower() not in ('ok', ''):
        raise RuntimeError(output)
    # Monitor rules are applied on a subsequent compositor frame.
    for _ in range(12):
        current = monitor()
        if current and current['name'] == m['name'] and current['width'] == m['width'] and current['height'] == m['height'] and abs(current['refreshRate'] - float(rate)) < 1:
            return
        time.sleep(.1)
    raise RuntimeError('Hyprland did not apply the requested refresh rate')


def option(name):
    value = json.loads(command(['hyprctl', 'getoption', name, '-j']))
    return bool(value.get('bool', value.get('int', 0)))


def set_option(name, value):
    if name not in ('decoration:blur:enabled', 'decoration:shadow:enabled', 'animations:enabled'):
        raise ValueError('Unsupported compositor power-saving option')
    expression = 'true' if value else 'false'
    for part in reversed(name.split(':')):
        expression = '{ ' + part + ' = ' + expression + ' }'
    output = command(['hyprctl', 'eval', 'hl.config(' + expression + ')'])
    if output.lower() not in ('ok', ''):
        raise RuntimeError(output)
    if option(name) != value:
        raise RuntimeError('Hyprland did not apply ' + name)


def backlight():
    devices = sorted(Path('/sys/class/backlight').glob('*'))
    if not devices:
        return None
    p = devices[0]
    return {'device': p.name, 'current': number(p / 'brightness'), 'maximum': number(p / 'max_brightness')}


def keyboard():
    p = Path('/sys/class/leds/dell::kbd_backlight')
    return {'current': number(p / 'brightness'), 'maximum': number(p / 'max_brightness')}


def set_light(device, value):
    command(['brightnessctl', '--device', device, 'set', str(value)])


def boost_permission_installed():
    return BOOST_HELPER.is_file() and BOOST_POLICY.is_file()


def boost_authorized():
    if not boost_permission_installed():
        return False
    try:
        # No --allow-user-interaction: background automation must never prompt.
        return subprocess.run(['pkcheck', '--action-id', 'org.local.quickshell.power.boost',
                               '--process', str(os.getpid())],
                              capture_output=True, timeout=5).returncode == 0
    except (OSError, subprocess.TimeoutExpired):
        return False


def set_cpu_values(boost, limit):
    if limit == number(CPU / 'max_perf_pct') and BOOST_HELPER.is_file():
        command(['pkexec', str(BOOST_HELPER), str(int(boost))], timeout=120)
    else:
        command(['pkexec', str(HELPER), 'cpu', str(int(boost)), str(limit)], timeout=120)


def charging():
    raw = read(BATTERY / 'charge_types', '')
    match = re.search(r'\[([^]]+)\]', raw)
    return {'mode': match.group(1) if match else '', 'modes': [s.strip('[]') for s in raw.split()],
            'start': number(BATTERY / 'charge_control_start_threshold'),
            'stop': number(BATTERY / 'charge_control_end_threshold'), 'cycles': number(BATTERY / 'cycle_count')}


def get_preferences():
    stored = load(CONFIG, {})
    result = {key: stored.get(key, value) if type(stored.get(key, value)) is type(value) else value
              for key, value in DEFAULTS.items()}
    for key, low, high in [('brightnessCap', 5, 100), ('lowThreshold', 5, 50), ('customLimit', 20, 100), ('customBrightness', 1, 100), ('customKeyboard', 0, 2)]:
        if not low <= result[key] <= high:
            result[key] = DEFAULTS[key]
    if result['customBase'] not in ('balanced', 'power-saver', 'performance'):
        result['customBase'] = 'balanced'
    return result


def get_state():
    state = load(STATE_FILE, {})
    return state if state.get('boot') == BOOT else {'boot': BOOT, 'overrides': {}}


def restore_overrides(state, allow_cpu=True):
    errors = []
    overrides = state.setdefault('overrides', {})
    for key, entry in list(overrides.items()):
        try:
            if key == 'brightness':
                light = backlight()
                if light and light['device'] == entry['device'] and light['current'] == entry['applied']:
                    set_light(entry['device'], entry['before'])
            elif key == 'keyboard':
                if keyboard()['current'] == entry['applied']:
                    set_light('dell::kbd_backlight', entry['before'])
            elif key == 'refresh':
                current = monitor()
                if current and monitor_signature(current) == entry['applied']:
                    set_monitor(entry['before'], entry['before']['refreshRate'])
            elif key == 'cpu':
                if not allow_cpu:
                    continue
                current = {'boost': read(CPU / 'no_turbo') == '0', 'limit': number(CPU / 'max_perf_pct')}
                restored = {name: entry['before'][name] if current[name] == entry['applied'][name] else current[name] for name in current}
                if restored != current:
                    set_cpu_values(restored['boost'], restored['limit'])
            elif key.startswith('effect:'):
                name = key.split(':', 1)[1]
                if option(name) == entry['applied']:
                    set_option(name, entry['before'])
            del overrides[key]
        except Exception as error:
            errors.append(str(error))
    state.pop('pendingDisplay', None)
    save(STATE_FILE, state)
    if errors:
        raise RuntimeError('; '.join(errors))


def apply_savings(state, prefs, confirm_display=True):
    overrides = state.setdefault('overrides', {})
    light = backlight()
    if prefs['limitBrightness'] and light:
        cap = max(1, round(light['maximum'] * prefs['brightnessCap'] / 100))
        if light['current'] > cap and 'brightness' not in overrides:
            overrides['brightness'] = {'device': light['device'], 'before': light['current'], 'applied': cap}
            save(STATE_FILE, state)
            set_light(light['device'], cap)
    if prefs['keyboardOff'] and keyboard()['current'] and 'keyboard' not in overrides:
        overrides['keyboard'] = {'before': keyboard()['current'], 'applied': 0}
        save(STATE_FILE, state)
        set_light('dell::kbd_backlight', 0)
    if prefs['reduceEffects']:
        for name in ['decoration:blur:enabled', 'decoration:shadow:enabled', 'animations:enabled']:
            key = 'effect:' + name
            if key not in overrides and option(name):
                overrides[key] = {'before': True, 'applied': False}
                save(STATE_FILE, state)
                set_option(name, False)
    if prefs['reduceRefresh'] and 'refresh' not in overrides:
        m = monitor()
        if m and m['refreshRate'] > 61:
            prefix = f"{m['width']}x{m['height']}@"
            supported = any(mode.startswith(prefix) and abs(float(mode.split('@')[1].rstrip('Hz')) - 60) < 1 for mode in m.get('availableModes', []))
            if not supported:
                raise RuntimeError('A 60 Hz mode is not available at the current resolution')
            applied = dict(m, refreshRate=60)
            overrides['refresh'] = {'before': m, 'applied': monitor_signature(applied)}
            if confirm_display:
                token = uuid.uuid4().hex
                state['pendingDisplay'] = {'token': token, 'deadline': time.time() + 15, 'ready': False}
            save(STATE_FILE, state)
            # An independent process restores the display even if Quickshell exits.
            if confirm_display:
                subprocess.Popen([sys.executable, str(Path(__file__).resolve()), 'watchdog', token],
                                 start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            try:
                set_monitor(m, 60)
            except Exception:
                current = monitor()
                # A rejected command must not leave a fake confirmation prompt.
                if current and monitor_signature(current) == overrides['refresh']['applied']:
                    set_monitor(m, m['refreshRate'])
                overrides.pop('refresh', None)
                state.pop('pendingDisplay', None)
                save(STATE_FILE, state)
                raise
            if confirm_display:
                state['pendingDisplay']['ready'] = True
    save(STATE_FILE, state)


def selected_mode(state, actual):
    if state.get('selectedMode') and state.get('selectedProfile') == actual:
        return state['selectedMode']
    return {'power-saver': 'saver', 'balanced': 'balanced', 'performance': 'performance'}.get(actual, '')


def apply_cpu_override(state, boost, limit):
    before = {'boost': read(CPU / 'no_turbo') == '0', 'limit': number(CPU / 'max_perf_pct')}
    applied = {'boost': boost, 'limit': limit}
    if before == applied:
        return
    if not HELPER.is_file():
        raise RuntimeError('The protected helper is needed to change CPU boost or limits')
    overrides = state.setdefault('overrides', {})
    overrides['cpu'] = {'before': before, 'applied': applied}
    save(STATE_FILE, state)
    set_cpu_values(boost, limit)


def apply_custom(state, prefs):
    overrides = state.setdefault('overrides', {})
    light = backlight()
    if prefs['customSetBrightness'] and light:
        value = prefs['customBrightness']
        if prefs['limitBrightness']:
            value = min(value, prefs['brightnessCap'])
        target = max(1, round(light['maximum'] * value / 100))
        overrides['brightness'] = {'device': light['device'], 'before': light['current'], 'applied': target}
        save(STATE_FILE, state)
        set_light(light['device'], target)
    if prefs['customSetKeyboard'] and keyboard()['current'] is not None:
        target = 0 if prefs['keyboardOff'] else prefs['customKeyboard']
        overrides['keyboard'] = {'before': keyboard()['current'], 'applied': target}
        save(STATE_FILE, state)
        set_light('dell::kbd_backlight', target)
    if prefs['customCpuEnabled']:
        if state.get('pendingDisplay'):
            # Do not hold the watchdog lock during an authentication prompt.
            raise RuntimeError('Confirm the display preview, then Apply Custom again to apply CPU limits')
        apply_cpu_override(state, prefs['customBoost'], prefs['customLimit'])
    apply_savings(state, prefs)


def change_mode(state, prefs, saver, manual=True):
    # Retain boolean/normal aliases for the automation and recovery command.
    mode = ('saver' if saver else 'balanced') if isinstance(saver, bool) else saver
    if mode == 'normal':
        mode = 'balanced'
    target = {'saver': 'power-saver', 'balanced': 'balanced', 'performance': 'performance', 'custom': prefs['customBase']}[mode]
    cpu_override = state.get('overrides', {}).get('cpu')
    if not manual and cpu_override and (cpu_override['before']['limit'] != cpu_override['applied']['limit'] or not boost_authorized()):
        raise RuntimeError('Automatic switching is paused while protected CPU overrides are active. Select a mode manually to authorize restoring them.')
    if not manual and mode == 'saver' and read(CPU / 'no_turbo') == '0' and not boost_authorized():
        raise RuntimeError('Select Power saving manually to authorize disabling CPU boost. Automatic switching will not open a password prompt.')
    if profile() is None:
        raise RuntimeError('Run the one-time power setup first: power-profiles-daemon is not available')
    if target == 'performance' and 'performance' not in profiles():
        raise RuntimeError('Performance mode is not supported by the current power-profile driver')
    # Undo the old mode before applying the next one; never stack presets.
    restore_overrides(state)
    command(PROFILE_BUS + ['set-property'] + PROFILE_OBJECT + ['s', target])
    if manual:
        state['manualOverride'] = True
    state['managedSaver'] = mode == 'saver'
    state['selectedMode'] = mode
    state['selectedProfile'] = target
    save(STATE_FILE, state)
    if mode == 'saver':
        # Disable boost without increasing or otherwise changing an existing limit.
        apply_cpu_override(state, False, number(CPU / 'max_perf_pct'))
        apply_savings(state, RECOMMENDED, confirm_display=False)
    elif mode == 'custom':
        apply_custom(state, prefs)


def reconcile_profile(state):
    """Respect another app's selection before considering any automation."""
    expected = state.get('selectedProfile', 'power-saver' if state.get('managedSaver') else None)
    if not expected or profile() in (None, expected):
        return False
    # Background reconciliation never requests administrator interaction. Keep
    # protected CPU recovery records until the user explicitly authorizes them.
    cpu = state.get('overrides', {}).get('cpu')
    allow_cpu = not cpu or (cpu['before']['limit'] == cpu['applied']['limit'] and boost_authorized())
    restore_overrides(state, allow_cpu=allow_cpu)
    state['managedSaver'] = False
    state['manualOverride'] = True
    state.pop('selectedMode', None)
    state.pop('selectedProfile', None)
    state.pop('autoReason', None)
    save(STATE_FILE, state)
    return True


def automation(state, prefs):
    status = read(BATTERY / 'status')
    on_battery = status == 'Discharging'
    capacity = number(BATTERY / 'capacity')
    previous = state.get('onBattery')
    state['onBattery'] = on_battery
    if previous is not None and previous != on_battery:
        state['manualOverride'] = False
    if reconcile_profile(state):
        return
    if not state.get('manualOverride'):
        low = prefs['autoLow'] and capacity is not None and capacity <= prefs['lowThreshold']
        if on_battery and (prefs['autoUnplug'] or low):
            if profile() not in (None, 'power-saver'):
                change_mode(state, prefs, True, manual=False)
                state['autoReason'] = 'unplug' if prefs['autoUnplug'] else 'low'
        elif not on_battery and prefs['normalOnAc'] and previous is True:
            if profile() is not None:
                change_mode(state, prefs, False, manual=False)
        elif state.get('autoReason') == 'low' and capacity is not None and capacity >= prefs['lowThreshold'] + 5 and not prefs['autoUnplug']:
            if profile() is not None:
                change_mode(state, prefs, False, manual=False)
            state.pop('autoReason', None)
    save(STATE_FILE, state)


def capabilities(state):
    # Cache display-only capabilities, never authorization decisions used to
    # apply or restore settings. Installation updates invalidate immediately.
    files = [HELPER, BOOST_HELPER, BOOST_POLICY, Path('/etc/polkit-1/rules.d/49-quickshell-boost.rules')]
    signature = []
    for path in files:
        try:
            info = path.stat()
            signature.append([str(path), info.st_mtime_ns, info.st_uid, info.st_mode])
        except OSError:
            signature.append([str(path), None])
    cached = state.get('capabilities', {})
    if not isinstance(cached, dict):
        cached = {}
    checked = cached.get('checked', 0)
    age = time.time() - checked if isinstance(checked, (int, float)) else -1
    values = cached.get('values', {})
    valid = isinstance(values, dict) and all(key in values for key in ('profiles', 'helperInstalled', 'boostPermissionInstalled', 'boostPasswordless'))
    if valid and cached.get('signature') == signature and 0 <= age < 60:
        return cached['values']
    helper_installed = HELPER.is_file() and HELPER.stat().st_uid == 0 and not HELPER.stat().st_mode & 0o022
    result = {'profiles': profiles(), 'helperInstalled': helper_installed,
              'boostPermissionInstalled': boost_permission_installed(), 'boostPasswordless': boost_authorized()}
    state['capabilities'] = {'checked': time.time(), 'signature': signature, 'values': result}
    save(STATE_FILE, state)
    return result


def status(prefs, state, error=''):
    m = monitor()
    actual = profile()
    supported = capabilities(state)
    cpu_override = state.get('overrides', {}).get('cpu')
    return {'prefs': prefs, 'profile': actual, **supported, 'selectedMode': selected_mode(state, actual),
            'customCpuActive': 'cpu' in state.get('overrides', {}),
            'cpuLimitOverrideActive': bool(cpu_override and cpu_override['before']['limit'] != cpu_override['applied']['limit']),
            'brightness': backlight(), 'keyboard': keyboard(), 'charging': charging(),
            'monitor': {'rate': round(m['refreshRate']), 'supports60': any(re.match(rf"^{m['width']}x{m['height']}@60(?:\.|Hz)", mode) for mode in m.get('availableModes', []))} if m else {},
            'cpu': {'boost': read(CPU / 'no_turbo') == '0', 'limit': number(CPU / 'max_perf_pct'),
                    'minimum': number(CPU / 'min_perf_pct'),
                    'preference': read('/sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference')},
            'pendingDisplay': state.get('pendingDisplay') if state.get('pendingDisplay', {}).get('ready', True) else None,
            'customized': bool(state.get('overrides')),
            'manualOverride': state.get('manualOverride', False), 'error': error}


def main(args):
    prefs, state = get_preferences(), get_state()
    action = args[0] if args else 'status'
    error = ''
    try:
        if action == 'prepare-uninstall':
            prefs = DEFAULTS.copy()
            save(CONFIG, prefs)
            state['manualOverride'] = True
            state['managedSaver'] = False
            state.pop('autoReason', None)
            save(STATE_FILE, state)
            restore_overrides(state)
        elif action == 'mode' and len(args) == 2 and args[1] in ('normal', 'balanced', 'performance', 'saver', 'custom'):
            change_mode(state, prefs, args[1])
        elif action == 'preference' and len(args) == 3:
            key, value = args[1], json.loads(args[2])
            if key not in DEFAULTS or type(value) is not type(DEFAULTS[key]):
                raise ValueError('Invalid preference')
            limits = {'brightnessCap': (5, 100), 'lowThreshold': (5, 50), 'customLimit': (20, 100), 'customBrightness': (1, 100), 'customKeyboard': (0, 2)}
            if key in limits and not limits[key][0] <= value <= limits[key][1]:
                raise ValueError('Preference is outside the supported range')
            if key == 'customBase' and value not in ('balanced', 'power-saver', 'performance'):
                raise ValueError('Unsupported Custom base profile')
            prefs[key] = value
            save(CONFIG, prefs)
            # Preset edits are saved, not silently applied to the current session.
        elif action == 'apply-preset':
            if selected_mode(state, profile()) != 'custom':
                raise RuntimeError('Select Custom before applying its configuration')
            change_mode(state, prefs, 'custom')
        elif action == 'brightness' and len(args) == 2:
            value = int(args[1])
            if not 1 <= value <= 100:
                raise ValueError('Brightness must be between 1% and 100%')
            light = backlight()
            if not light:
                raise RuntimeError('No display backlight found')
            target = max(1, round(light['maximum'] * value / 100))
            overrides = state.setdefault('overrides', {})
            if selected_mode(state, profile()) == 'custom':
                original = overrides.get('brightness', {}).get('before', light['current'])
                overrides['brightness'] = {'device': light['device'], 'before': original, 'applied': target}
                prefs.update(customSetBrightness=True, customBrightness=value)
                save(CONFIG, prefs)
            else:
                overrides.pop('brightness', None)
            save(STATE_FILE, state)
            set_light(light['device'], target)
            save(STATE_FILE, state)
        elif action == 'keyboard' and len(args) == 2:
            value = int(args[1])
            if not 0 <= value <= (keyboard()['maximum'] or 0):
                raise ValueError('Unsupported keyboard brightness')
            overrides = state.setdefault('overrides', {})
            if selected_mode(state, profile()) == 'custom':
                original = overrides.get('keyboard', {}).get('before', keyboard()['current'])
                overrides['keyboard'] = {'before': original, 'applied': value}
                prefs.update(customSetKeyboard=True, customKeyboard=value, keyboardOff=False)
                save(CONFIG, prefs)
            else:
                overrides.pop('keyboard', None)
            save(STATE_FILE, state)
            set_light('dell::kbd_backlight', value)
            save(STATE_FILE, state)
        elif action in ('cpu', 'charging'):
            if state.get('pendingDisplay'):
                raise RuntimeError('Confirm or revert the display preview before requesting authorization')
            if not HELPER.is_file():
                raise RuntimeError('Install the protected helper using the one-time setup command')
            command(['pkexec', str(HELPER), *args], timeout=120)
        elif action == 'confirm-display':
            state.pop('pendingDisplay', None)
            save(STATE_FILE, state)
        elif action == 'revert-display':
            entry = state.setdefault('overrides', {}).get('refresh')
            if entry:
                current = monitor()
                if current and monitor_signature(current) == entry['applied']:
                    set_monitor(entry['before'], entry['before']['refreshRate'])
                del state['overrides']['refresh']
            state.pop('pendingDisplay', None)
            save(STATE_FILE, state)
        elif action == 'tick':
            automation(state, prefs)
        elif action == 'reconcile':
            reconcile_profile(state)
        elif action == 'watchdog' and len(args) == 2:
            pending = state.get('pendingDisplay', {})
            if pending.get('token') == args[1] and time.time() >= pending['deadline']:
                main(['revert-display'])
            return
        elif action != 'status':
            raise ValueError('Unknown power action')
    except Exception as exception:
        error = str(exception)
    print(json.dumps(status(prefs, state, error)))


if __name__ == '__main__':
    if len(sys.argv) > 1 and sys.argv[1] == 'watchdog':
        time.sleep(16)
        # A confirmed preview or completed uninstall must not recreate state files.
        if get_state().get('pendingDisplay', {}).get('token') != sys.argv[2]:
            sys.exit(0)
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    with (STATE_DIR / 'power.lock').open('w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        main(sys.argv[1:])
