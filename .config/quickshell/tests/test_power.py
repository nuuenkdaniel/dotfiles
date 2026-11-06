import importlib.util
import contextlib
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch


def module(name, filename):
    spec = importlib.util.spec_from_file_location(name, Path(__file__).resolve().parents[1] / 'bin' / filename)
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


power = module('power', 'power.py')
control = module('power_control', 'power-control.py')
boost_control = module('boost_control', 'boost-control.py')
uninstall = module('uninstall_power', 'uninstall-power.py')


class PowerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(dir='/tmp/opencode')
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name)
        for name, value in [('CONFIG', self.directory / 'prefs.json'),
                            ('STATE_FILE', self.directory / 'state.json')]:
            p = patch.object(power, name, value)
            p.start()
            self.addCleanup(p.stop)

    def test_defaults_do_not_enable_savings_or_automation(self):
        prefs = power.get_preferences()
        for key in ['limitBrightness', 'reduceRefresh', 'keyboardOff', 'reduceEffects', 'autoLow', 'autoUnplug', 'normalOnAc']:
            self.assertFalse(prefs[key])

    def test_invalid_saved_preferences_are_rejected(self):
        power.CONFIG.write_text(json.dumps({'limitBrightness': 'yes', 'brightnessCap': -10, 'lowThreshold': True}))
        prefs = power.get_preferences()
        self.assertFalse(prefs['limitBrightness'])
        self.assertEqual(prefs['brightnessCap'], 40)
        self.assertEqual(prefs['lowThreshold'], 20)

    def test_session_is_boot_scoped(self):
        power.STATE_FILE.write_text(json.dumps({'boot': 'another-boot', 'overrides': {'brightness': 123}}))
        self.assertEqual(power.get_state(), {'boot': power.BOOT, 'overrides': {}})

    def test_brightness_cap_never_raises_brightness(self):
        state = {'boot': power.BOOT, 'overrides': {}}
        prefs = dict(power.DEFAULTS, limitBrightness=True, brightnessCap=40)
        with patch.object(power, 'backlight', return_value={'device': 'test', 'current': 20, 'maximum': 100}), patch.object(power, 'set_light') as writer:
            power.apply_savings(state, prefs)
            writer.assert_not_called()
            self.assertEqual(state['overrides'], {})

    def test_brightness_cap_records_original_and_applied_values(self):
        state = {'boot': power.BOOT, 'overrides': {}}
        prefs = dict(power.DEFAULTS, limitBrightness=True, brightnessCap=40)
        with patch.object(power, 'backlight', return_value={'device': 'test', 'current': 80, 'maximum': 100}), patch.object(power, 'set_light') as writer:
            power.apply_savings(state, prefs)
            writer.assert_called_once_with('test', 40)
            self.assertEqual(state['overrides']['brightness']['before'], 80)

    def test_restore_respects_later_manual_changes(self):
        state = {'boot': power.BOOT, 'overrides': {'brightness': {'device': 'test', 'before': 80, 'applied': 40}}}
        with patch.object(power, 'backlight', return_value={'device': 'test', 'current': 25, 'maximum': 100}), patch.object(power, 'set_light') as writer:
            power.restore_overrides(state)
            writer.assert_not_called()
            self.assertEqual(state['overrides'], {})

    def test_restore_original_brightness_when_still_owned(self):
        state = {'boot': power.BOOT, 'overrides': {'brightness': {'device': 'test', 'before': 80, 'applied': 40}}}
        with patch.object(power, 'backlight', return_value={'device': 'test', 'current': 40, 'maximum': 100}), patch.object(power, 'set_light') as writer:
            power.restore_overrides(state)
            writer.assert_called_once_with('test', 80)

    def test_saver_is_unavailable_without_daemon(self):
        with patch.object(power, 'profile', return_value=None), patch.object(power, 'command') as command:
            with self.assertRaisesRegex(RuntimeError, 'setup'):
                power.change_mode({'overrides': {}}, power.DEFAULTS, True)
            command.assert_not_called()

    def test_profile_uses_dbus_without_python_gobject_cli(self):
        with patch.object(power, 'command', return_value='s "balanced"') as command:
            self.assertEqual(power.profile(), 'balanced')
            self.assertEqual(command.call_args.args[0][0], 'busctl')

    def test_profile_handles_missing_service(self):
        with patch.object(power, 'command', side_effect=RuntimeError('Service unavailable')):
            self.assertIsNone(power.profile())

    def test_performance_capability_comes_from_daemon(self):
        value = {'data': [{'Profile': {'data': 'balanced'}}, {'Profile': {'data': 'performance'}}]}
        with patch.object(power, 'command', return_value=json.dumps(value)):
            self.assertEqual(power.profiles(), ['balanced', 'performance'])

    def test_recommended_preset_is_separate_from_custom(self):
        state = {'boot': power.BOOT, 'overrides': {}}
        prefs = dict(power.DEFAULTS, brightnessCap=15, reduceRefresh=True)
        with patch.object(power, 'profile', return_value='balanced'), patch.object(power, 'command'), patch.object(power, 'restore_overrides') as restore, patch.object(power, 'apply_cpu_override') as cpu, patch.object(power, 'apply_savings') as apply:
            power.change_mode(state, prefs, 'saver')
            restore.assert_called_once_with(state)
            self.assertEqual(apply.call_args.args[1]['brightnessCap'], 40)
            self.assertTrue(apply.call_args.args[1]['reduceRefresh'])
            self.assertFalse(apply.call_args.args[1]['keyboardOff'])
            self.assertFalse(cpu.call_args.args[1])
            self.assertEqual(state['selectedMode'], 'saver')

    def test_boost_override_preserves_existing_cpu_limit(self):
        state = {'boot': power.BOOT, 'overrides': {}}
        with patch.object(power, 'read', return_value='0'), patch.object(power, 'number', return_value=80), patch.object(power, 'HELPER') as helper, patch.object(power, 'BOOST_HELPER') as boost, patch.object(power, 'command') as command:
            helper.is_file.return_value = True
            boost.is_file.return_value = False
            power.apply_cpu_override(state, False, 80)
            self.assertEqual(command.call_args.args[0][-2:], ['0', '80'])
            self.assertEqual(state['overrides']['cpu']['before'], {'boost': True, 'limit': 80})

    def test_boost_only_changes_use_narrow_entry_point(self):
        with patch.object(power, 'number', return_value=100), patch.object(power, 'BOOST_HELPER') as helper, patch.object(power, 'command') as command:
            helper.is_file.return_value = True
            power.set_cpu_values(False, 100)
            self.assertEqual(command.call_args.args[0], ['pkexec', str(helper), '0'])

    def test_custom_limit_changes_do_not_use_boost_permission(self):
        with patch.object(power, 'number', return_value=100), patch.object(power, 'BOOST_HELPER') as boost, patch.object(power, 'command') as command:
            boost.is_file.return_value = True
            power.set_cpu_values(False, 60)
            self.assertEqual(command.call_args.args[0], ['pkexec', str(power.HELPER), 'cpu', '0', '60'])

    def test_background_authorization_check_never_requests_interaction(self):
        with patch.object(power, 'boost_permission_installed', return_value=True), patch.object(power.subprocess, 'run') as run:
            run.return_value.returncode = 0
            self.assertTrue(power.boost_authorized())
            self.assertNotIn('--allow-user-interaction', run.call_args.args[0])
            self.assertNotIn('--detail', run.call_args.args[0])

    def test_boost_policy_binds_only_the_boost_executable(self):
        import xml.etree.ElementTree as ET
        directory = Path(__file__).resolve().parents[1] / 'bin'
        action = ET.parse(directory / 'org.local.quickshell.power.boost.policy').getroot().find('action')
        self.assertEqual(action.attrib['id'], 'org.local.quickshell.power.boost')
        self.assertEqual(action.find('annotate').text, '/usr/local/libexec/quickshell-boost-control')
        rule = (directory / 'power-boost.rules.in').read_text()
        self.assertIn('subject.user === __USER_JSON__', rule)
        self.assertIn('subject.local && subject.active', rule)
        self.assertNotIn('action.lookup(', rule)

    def test_already_disabled_boost_does_not_prompt(self):
        with patch.object(power, 'read', return_value='1'), patch.object(power, 'number', return_value=100), patch.object(power, 'command') as command:
            power.apply_cpu_override({'overrides': {}}, False, 100)
            command.assert_not_called()

    def test_custom_mode_uses_saved_base_and_configuration(self):
        state = {'boot': power.BOOT, 'overrides': {}}
        prefs = dict(power.DEFAULTS, customBase='power-saver', brightnessCap=25)
        with patch.object(power, 'profile', return_value='balanced'), patch.object(power, 'command') as command, patch.object(power, 'restore_overrides'), patch.object(power, 'apply_custom') as apply:
            power.change_mode(state, prefs, 'custom')
            self.assertEqual(command.call_args.args[0][-1], 'power-saver')
            apply.assert_called_once_with(state, prefs)
            self.assertEqual(state['selectedMode'], 'custom')

    def test_external_profile_change_clears_custom_selection(self):
        state = {'selectedMode': 'custom', 'selectedProfile': 'balanced'}
        self.assertEqual(power.selected_mode(state, 'performance'), 'performance')

    def test_performance_mode_is_rejected_if_unavailable(self):
        with patch.object(power, 'profile', return_value='balanced'), patch.object(power, 'profiles', return_value=['balanced', 'power-saver']), patch.object(power, 'command') as command:
            with self.assertRaisesRegex(RuntimeError, 'not supported'):
                power.change_mode({'overrides': {}}, power.DEFAULTS, 'performance')
            command.assert_not_called()

    def test_background_restore_does_not_request_cpu_authorization(self):
        entry = {'before': {'boost': True, 'limit': 100}, 'applied': {'boost': False, 'limit': 60}}
        state = {'boot': power.BOOT, 'overrides': {'cpu': entry}}
        with patch.object(power, 'command') as command:
            power.restore_overrides(state, allow_cpu=False)
            command.assert_not_called()
            self.assertEqual(state['overrides']['cpu'], entry)

    def test_automation_does_not_open_cpu_authorization_prompt(self):
        state = {'overrides': {'cpu': {'before': {'boost': True, 'limit': 100}, 'applied': {'boost': False, 'limit': 60}}}}
        with patch.object(power, 'command') as command:
            with self.assertRaisesRegex(RuntimeError, 'Select a mode manually'):
                power.change_mode(state, power.DEFAULTS, True, manual=False)
            command.assert_not_called()

    def test_manual_mode_pauses_automation(self):
        state = {'boot': power.BOOT, 'overrides': {}, 'onBattery': True, 'manualOverride': True}
        with patch.object(power, 'read', return_value='Discharging'), patch.object(power, 'number', return_value=10), patch.object(power, 'change_mode') as change:
            power.automation(state, dict(power.DEFAULTS, autoLow=True))
            change.assert_not_called()

    def test_unplug_clears_manual_override(self):
        state = {'boot': power.BOOT, 'overrides': {}, 'onBattery': False, 'manualOverride': True}
        with patch.object(power, 'read', return_value='Discharging'), patch.object(power, 'number', return_value=60), patch.object(power, 'profile', return_value='balanced'), patch.object(power, 'change_mode') as change:
            power.automation(state, dict(power.DEFAULTS, autoUnplug=True))
            self.assertFalse(state['manualOverride'])
            change.assert_called_once_with(state, dict(power.DEFAULTS, autoUnplug=True), True, manual=False)

    def test_low_battery_hysteresis(self):
        state = {'boot': power.BOOT, 'overrides': {}, 'onBattery': True, 'autoReason': 'low'}
        with patch.object(power, 'read', return_value='Discharging'), patch.object(power, 'number', return_value=23), patch.object(power, 'profile', return_value='power-saver'), patch.object(power, 'change_mode') as change:
            power.automation(state, dict(power.DEFAULTS, autoLow=True, lowThreshold=20))
            change.assert_not_called()

    def test_external_profile_is_reconciled_before_automatic_saver(self):
        state = {'boot': power.BOOT, 'overrides': {}, 'onBattery': True,
                 'selectedProfile': 'power-saver', 'selectedMode': 'saver', 'managedSaver': True}
        prefs = dict(power.DEFAULTS, autoUnplug=True)
        with patch.object(power, 'read', return_value='Discharging'), patch.object(power, 'number', return_value=50), patch.object(power, 'profile', return_value='balanced'), patch.object(power, 'restore_overrides') as restore, patch.object(power, 'change_mode') as change:
            power.automation(state, prefs)
            power.automation(state, prefs)
            change.assert_not_called()
            restore.assert_called_once_with(state, allow_cpu=True)
        self.assertTrue(state['manualOverride'])
        self.assertNotIn('selectedProfile', state)

    def test_profile_reconciliation_works_without_automation_and_never_prompts(self):
        cpu = {'before': {'boost': True, 'limit': 100}, 'applied': {'boost': False, 'limit': 60}}
        state = {'overrides': {'cpu': cpu}, 'selectedProfile': 'balanced', 'selectedMode': 'custom'}
        with patch.object(power, 'profile', return_value='performance'), patch.object(power, 'command') as command, patch.object(power, 'restore_overrides') as restore:
            self.assertTrue(power.reconcile_profile(state))
            restore.assert_called_once_with(state, allow_cpu=False)
            command.assert_not_called()
        self.assertTrue(state['manualOverride'])

    def test_internal_matching_profile_does_not_restore_or_pause_automation(self):
        state = {'selectedProfile': 'power-saver'}
        with patch.object(power, 'profile', return_value='power-saver'), patch.object(power, 'restore_overrides') as restore:
            self.assertFalse(power.reconcile_profile(state))
            restore.assert_not_called()
        self.assertNotIn('manualOverride', state)

    def test_capabilities_are_cached_instead_of_probing_every_status_refresh(self):
        state = {'boot': power.BOOT}
        with patch.object(power, 'profiles', return_value=['balanced', 'power-saver']) as profiles, patch.object(power, 'boost_authorized', return_value=False) as permission:
            first = power.capabilities(state)
            second = power.capabilities(state)
            self.assertEqual(first, second)
            profiles.assert_called_once()
            permission.assert_called_once()
            state['capabilities']['checked'] -= 61
            power.capabilities(state)
            self.assertEqual(profiles.call_count, 2)
            self.assertEqual(permission.call_count, 2)

    def test_cached_display_authorization_is_never_used_for_enforcement(self):
        state = {'overrides': {}, 'capabilities': {'values': {'boostPasswordless': True}}}
        with patch.object(power, 'read', return_value='0'), patch.object(power, 'boost_authorized', return_value=False), patch.object(power, 'command') as command:
            with self.assertRaisesRegex(RuntimeError, 'Automatic switching'):
                power.change_mode(state, power.DEFAULTS, True, manual=False)
            command.assert_not_called()

    def test_invalid_refresh_mode_does_not_change_display(self):
        state = {'boot': power.BOOT, 'overrides': {}}
        m = {'name': 'eDP-1', 'width': 2880, 'height': 1800, 'refreshRate': 120, 'availableModes': ['2880x1800@120.00Hz']}
        with patch.object(power, 'backlight', return_value=None), patch.object(power, 'monitor', return_value=m), patch.object(power, 'set_monitor') as setter:
            with self.assertRaisesRegex(RuntimeError, '60 Hz'):
                power.apply_savings(state, dict(power.DEFAULTS, reduceRefresh=True))
            setter.assert_not_called()

    def test_display_preview_starts_independent_watchdog(self):
        state = {'boot': power.BOOT, 'overrides': {}}
        m = {'name': 'eDP-1', 'width': 2880, 'height': 1800, 'refreshRate': 120,
             'x': 0, 'y': 0, 'scale': 1.6666666, 'transform': 0,
             'availableModes': ['2880x1800@120.00Hz', '2880x1800@60.00Hz']}
        with patch.object(power, 'backlight', return_value=None), patch.object(power, 'monitor', return_value=m), patch.object(power, 'set_monitor') as setter, patch.object(power.subprocess, 'Popen') as spawn:
            power.apply_savings(state, dict(power.DEFAULTS, reduceRefresh=True))
            setter.assert_called_once_with(m, 60)
            self.assertIn('pendingDisplay', state)
            self.assertEqual(state['overrides']['refresh']['before'], m)
            self.assertTrue(spawn.call_args.kwargs['start_new_session'])

    def test_standard_preset_does_not_start_display_revert_timer(self):
        state = {'boot': power.BOOT, 'overrides': {}}
        m = {'name': 'eDP-1', 'width': 2880, 'height': 1800, 'refreshRate': 120,
             'x': 0, 'y': 0, 'scale': 1.6666666, 'transform': 0,
             'availableModes': ['2880x1800@120.00Hz', '2880x1800@60.00Hz']}
        with patch.object(power, 'backlight', return_value=None), patch.object(power, 'monitor', return_value=m), patch.object(power, 'set_monitor') as setter, patch.object(power.subprocess, 'Popen') as spawn:
            power.apply_savings(state, dict(power.DEFAULTS, reduceRefresh=True), confirm_display=False)
            setter.assert_called_once_with(m, 60)
            spawn.assert_not_called()
            self.assertNotIn('pendingDisplay', state)
            self.assertIn('refresh', state['overrides'])

    def test_monitor_change_uses_lua_and_verifies_actual_rate(self):
        m = {'name': 'eDP-1', 'width': 2880, 'height': 1800, 'refreshRate': 120,
             'x': 0, 'y': 0, 'scale': 1.6666666, 'transform': 0, 'vrr': False}
        with patch.object(power, 'command', return_value='ok') as command, patch.object(power, 'monitor', return_value=dict(m, refreshRate=60)):
            power.set_monitor(m, 60)
            args = command.call_args.args[0]
            self.assertEqual(args[:2], ['hyprctl', 'eval'])
            self.assertIn('hl.monitor', args[2])
            self.assertIn('2880x1800@60', args[2])
            self.assertNotIn('vrr', args[2])

    def test_effect_change_uses_lua_config(self):
        with patch.object(power, 'command', return_value='ok') as command, patch.object(power, 'option', return_value=False):
            power.set_option('decoration:blur:enabled', False)
            self.assertEqual(command.call_args.args[0], ['hyprctl', 'eval', 'hl.config({ decoration = { blur = { enabled = false } } })'])

    def test_rejected_display_change_clears_preview_and_snapshot(self):
        state = {'boot': power.BOOT, 'overrides': {}}
        m = {'name': 'eDP-1', 'width': 2880, 'height': 1800, 'refreshRate': 120,
             'x': 0, 'y': 0, 'scale': 1.6666666, 'transform': 0,
             'availableModes': ['2880x1800@120.00Hz', '2880x1800@60.00Hz']}
        with patch.object(power, 'backlight', return_value=None), patch.object(power, 'monitor', return_value=m), patch.object(power, 'set_monitor', side_effect=RuntimeError('rejected')), patch.object(power.subprocess, 'Popen'):
            with self.assertRaisesRegex(RuntimeError, 'rejected'):
                power.apply_savings(state, dict(power.DEFAULTS, reduceRefresh=True))
            self.assertNotIn('pendingDisplay', state)
            self.assertNotIn('refresh', state['overrides'])

    def test_display_restore_does_not_override_changed_layout(self):
        m = {'name': 'eDP-1', 'width': 2880, 'height': 1800, 'refreshRate': 60,
             'x': 0, 'y': 0, 'scale': 1.6666666, 'transform': 0}
        state = {'boot': power.BOOT, 'overrides': {'refresh': {'before': dict(m, refreshRate=120), 'applied': power.monitor_signature(m)}}}
        with patch.object(power, 'monitor', return_value=dict(m, x=1920)), patch.object(power, 'set_monitor') as setter:
            power.restore_overrides(state)
            setter.assert_not_called()

    def test_restore_failure_retains_recovery_snapshot(self):
        state = {'boot': power.BOOT, 'overrides': {'brightness': {'device': 'test', 'before': 80, 'applied': 40}}}
        with patch.object(power, 'backlight', return_value={'device': 'test', 'current': 40, 'maximum': 100}), patch.object(power, 'set_light', side_effect=RuntimeError('device unavailable')):
            with self.assertRaisesRegex(RuntimeError, 'device unavailable'):
                power.restore_overrides(state)
            self.assertIn('brightness', state['overrides'])

    def test_changed_effect_settings_are_not_restored(self):
        state = {'boot': power.BOOT, 'overrides': {'effect:animations:enabled': {'before': True, 'applied': False}}}
        with patch.object(power, 'option', return_value=True), patch.object(power, 'set_option') as setter:
            power.restore_overrides(state)
            setter.assert_not_called()


class ProtectedHelperTests(unittest.TestCase):
    def test_boost_helper_rejects_extra_arguments_and_arbitrary_values(self):
        with patch.object(boost_control.os, 'geteuid', return_value=0), patch.object(boost_control.Path, 'write_text') as write:
            for args in [[], ['2'], ['cpu', '0', '100'], ['0', '/etc/passwd'], ['0;reboot']]:
                with self.assertRaises(ValueError):
                    boost_control.main(args)
            write.assert_not_called()

    def test_boost_helper_requires_root(self):
        with patch.object(boost_control.os, 'geteuid', return_value=1000):
            with self.assertRaises(PermissionError):
                boost_control.main(['0'])

    def test_uninstall_removes_only_tracked_boost_permission_files(self):
        with tempfile.TemporaryDirectory(dir='/tmp/opencode') as directory:
            root = Path(directory)
            install = root / 'install'
            install.mkdir()
            record = install / 'install.json'
            record.write_text(json.dumps({'version': 1, 'boostPermissionManaged': True}))
            helper = root / 'helper'
            helper.write_text('helper')
            files = [root / 'boost', root / 'policy', root / 'rules']
            for path in files:
                path.write_text('managed')
            unrelated = root / 'other-policy'
            unrelated.write_text('keep')
            with patch.object(control, 'INSTALL_DIR', install), patch.object(control, 'INSTALL_RECORD', record), patch.object(control, 'INSTALLED_HELPER', helper), patch.object(control, '__file__', str(helper)), patch.object(control, 'BOOST_FILES', files):
                control.remove_installation()
            self.assertFalse(helper.exists())
            self.assertFalse(install.exists())
            self.assertTrue(all(not path.exists() for path in files))
            self.assertEqual(unrelated.read_text(), 'keep')
    def test_installation_baseline_is_not_overwritten(self):
        with tempfile.TemporaryDirectory(dir='/tmp/opencode') as directory:
            root = Path(directory)
            cpu, battery = root / 'cpu', root / 'battery'
            cpu.mkdir()
            battery.mkdir()
            for name, value in [('no_turbo', '0'), ('max_perf_pct', '100')]:
                (cpu / name).write_text(value)
            for name, value in [('charge_types', 'Trickle [Fast] Standard Adaptive Custom'),
                                ('charge_control_start_threshold', '50'), ('charge_control_end_threshold', '90')]:
                (battery / name).write_text(value)
            with patch.object(control, 'CPU', cpu), patch.object(control, 'BATTERY', battery), patch.object(control, 'INSTALL_DIR', root / 'install'), patch.object(control, 'INSTALL_RECORD', root / 'install/install.json'):
                control.snapshot('0', '0', '0', 'unknown')
                first = control.INSTALL_RECORD.read_text()
                self.assertFalse(json.loads(first)['packagePresent'])
                self.assertEqual(json.loads(first)['charging']['mode'], 'Fast')
                (cpu / 'no_turbo').write_text('1')
                control.snapshot('1', '1', '1', 'power-saver')
                self.assertEqual(first, control.INSTALL_RECORD.read_text())

    def test_restore_thresholds_even_when_original_mode_was_not_custom(self):
        values = {'mode': 'Custom', 'charge_control_start_threshold': '60', 'charge_control_end_threshold': '80'}

        class FirmwareFile:
            def __init__(self, name):
                self.name = name

            def read_text(self):
                if self.name == 'charge_types':
                    return ' '.join('[' + m + ']' if m == values['mode'] else m for m in ['Fast', 'Custom'])
                return values[self.name]

            def write_text(self, value):
                values['mode' if self.name == 'charge_types' else self.name] = value.strip()

        class Firmware:
            def __truediv__(self, name):
                return FirmwareFile(name)

        with patch.object(control, 'BATTERY', Firmware()):
            control.set_charging('Fast', 50, 90, restore_thresholds=True)
        self.assertEqual(values, {'mode': 'Fast', 'charge_control_start_threshold': '50', 'charge_control_end_threshold': '90'})

    def test_integer_rejects_shell_and_path_inputs(self):
        for invalid in ['1;reboot', '../../etc/passwd', '1.5', '-1', '101']:
            with self.assertRaises(ValueError):
                control.integer(invalid, 0, 100)

    def test_cpu_limit_validation_and_readback(self):
        with tempfile.TemporaryDirectory(dir='/tmp/opencode') as directory:
            cpu = Path(directory)
            for name, value in [('min_perf_pct', '9'), ('max_perf_pct', '100'), ('no_turbo', '0')]:
                (cpu / name).write_text(value)
            with patch.object(control, 'CPU', cpu):
                control.set_cpu('0', '60')
                self.assertEqual((cpu / 'no_turbo').read_text().strip(), '1')
                self.assertEqual((cpu / 'max_perf_pct').read_text().strip(), '60')
                with self.assertRaises(ValueError):
                    control.set_cpu('1', '10')

    def test_charging_rejects_bad_mode_and_threshold_gap_before_writing(self):
        with tempfile.TemporaryDirectory(dir='/tmp/opencode') as directory:
            battery = Path(directory)
            (battery / 'charge_types').write_text('Trickle [Fast] Standard Adaptive Custom')
            with patch.object(control, 'BATTERY', battery), patch.object(control, 'write_checked') as writer:
                for mode, start, stop in [('invalid', 50, 90), ('Custom', 90, 91), ('Custom', 40, 90)]:
                    with self.assertRaises(ValueError):
                        control.set_charging(mode, start, stop)
                writer.assert_not_called()


class UninstallTests(unittest.TestCase):
    def test_indicator_cleanup_preserves_battery_display(self):
        source = (uninstall.ROOT / 'components/InfoTray.qml').read_text()
        cleaned = uninstall.indicator_without_battery(source)
        self.assertNotIn('PowerProfiles', cleaned)
        self.assertNotIn('root.powerSaving', cleaned)
        self.assertIn('text: root.batteryGlyph', cleaned)
        self.assertIn('text: root.batteryLevel', cleaned)
    def test_source_cleanup_preserves_other_tabs(self):
        source = (uninstall.ROOT / 'components/SettingsMenu.qml').read_text()
        cleaned = uninstall.settings_without_battery(source)
        self.assertNotIn('PowerManagement', cleaned)
        self.assertNotIn('BatterySettings', cleaned)
        self.assertIn('model: root.baseTabs', cleaned)
        self.assertIn('"Notifications", "About"', cleaned)
        self.assertIn('ConnectivitySettings {', cleaned)
        self.assertIn('component DeviceRow:', cleaned)

    def test_missing_marker_aborts_instead_of_guessing(self):
        source = (uninstall.ROOT / 'components/SettingsMenu.qml').read_text()
        with self.assertRaises(RuntimeError):
            uninstall.settings_without_battery(source.replace('// BEGIN BATTERY PAGE', '// edited marker'))

    def test_cancel_does_not_run_cleanup(self):
        with patch.object(uninstall.os, 'geteuid', return_value=1000), patch.object(uninstall.sys, 'argv', ['uninstall-power.py']), patch('builtins.input', return_value='no'), patch.object(uninstall, 'run') as runner, contextlib.redirect_stdout(io.StringIO()):
            uninstall.main()
            runner.assert_not_called()

    def test_full_source_cleanup_only_removes_owned_files(self):
        with tempfile.TemporaryDirectory(dir='/tmp/opencode') as directory:
            root = Path(directory)
            for subdir in ['components', 'globals', 'bin', 'tests', 'state', 'config']:
                (root / subdir).mkdir()
            original = (uninstall.ROOT / 'components/SettingsMenu.qml').read_text()
            (root / 'components/SettingsMenu.qml').write_text(original)
            (root / 'components/InfoTray.qml').write_text((uninstall.ROOT / 'components/InfoTray.qml').read_text())
            (root / 'globals/qmldir').write_text('singleton GlobalMenuState 1.0 GlobalMenuState.qml\nsingleton PowerManagement 1.0 PowerManagement.qml\n')
            (root / 'components/BatterySettings.qml').write_text('battery')
            (root / 'components/VolumeOSD.qml').write_text('keep my OSD')
            (root / 'config/battery-preferences.json').write_text('{}')
            (root / 'state/power-session.json').write_text('{}')
            (root / 'state/power.lock').write_text('')
            (root / 'state/unrelated.json').write_text('keep my state')
            with patch.object(uninstall, 'ROOT', root), patch.object(uninstall, 'CONFIG', root / 'config'), patch.object(uninstall, 'STATE', root / 'state'), patch.object(uninstall, 'HELPER', root / 'missing-helper'), patch.object(uninstall, 'SYSTEM_STATE_DIR', root / 'missing-system-state'), patch.object(uninstall.os, 'geteuid', return_value=1000), patch.object(uninstall.sys, 'argv', ['uninstall-power.py']), patch('builtins.input', return_value='REMOVE'), patch.object(uninstall, 'run', return_value='{"error": ""}'), patch.object(uninstall.time, 'sleep'), contextlib.redirect_stdout(io.StringIO()):
                uninstall.main()
            self.assertFalse((root / 'components/BatterySettings.qml').exists())
            self.assertFalse((root / 'config/battery-preferences.json').exists())
            self.assertFalse((root / 'state/power-session.json').exists())
            self.assertFalse((root / 'state/power.lock').exists())
            self.assertEqual((root / 'components/VolumeOSD.qml').read_text(), 'keep my OSD')
            self.assertEqual((root / 'state/unrelated.json').read_text(), 'keep my state')
            self.assertNotIn('BatterySettings', (root / 'components/SettingsMenu.qml').read_text())
            self.assertIn('GlobalMenuState', (root / 'globals/qmldir').read_text())


if __name__ == '__main__':
    unittest.main()
