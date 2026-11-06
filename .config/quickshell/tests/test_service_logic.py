import json
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]


def qml_functions(path, names):
    source = (ROOT / path).read_text()
    result = []
    for name in names:
        start = source.index('  function ' + name + '(')
        brace = source.index('{', start)
        depth, end = 1, brace + 1
        while depth:
            if source[end] == '{': depth += 1
            elif source[end] == '}': depth -= 1
            end += 1
        result.append(source[start:end])
    return '\n'.join(result)


@unittest.skipUnless(shutil.which('node'), 'Node is needed for worker lifecycle tests')
class PowerWorkerLifecycle(unittest.TestCase):
    def evaluate(self, expression):
        names = ['run', 'next', 'evaluateAutomation', 'reconcileProfile', 'flushBackground',
                 'checkWorker', 'finishRequest', 'drainQueue']
        functions = qml_functions('globals/PowerManagement.qml', names)
        bindings = '\n'.join('root.' + name + '=' + name + ';' for name in names)
        fixtures = '''
            const tasks = [], events = [];
            const Qt = {callLater:f => tasks.push(f)};
            const worker = {running:false,command:[]};
            const root = {queue:[], currentAction:[], output:'', executing:false,
                script:'/test/power.py',state:{}, error:'', automationEnabled:false,
                pendingAutomation:false,pendingReconcile:false,
                actionFinished:(action,success) => events.push([action,success])};
            function flush() {let count=0; while(tasks.length) {if (++count>100) throw Error('Queue loop'); tasks.shift()();}}
            function finish() {worker.running=false; root.output='{"prefs":{}}'; root.finishRequest(0,''); flush();}
        '''
        script = fixtures + '\nwith(root) {\n' + functions + '\n' + bindings + '\n}\nconsole.log(JSON.stringify((() => {' + expression + '})()))'
        return json.loads(subprocess.check_output(['node', '-e', script], text=True))

    def test_failed_start_releases_busy_state_and_continues_queued_requests(self):
        result = self.evaluate('''
            root.run(['mode','balanced']); root.run(['preference','autoLow','true']);
            worker.running=false; root.checkWorker(); flush();
            const next=root.currentAction[0];
            worker.running=false; root.checkWorker(); flush();
            return [next,root.executing,root.queue.length,events];
        ''')
        self.assertEqual(result, ['preference', False, 0, [['mode', False], ['preference', False]]])

    def test_profile_events_are_serviced_even_with_automation_disabled(self):
        result = self.evaluate('''
            root.run(['status']); root.reconcileProfile(); finish();
            return [root.currentAction[0],root.executing,root.pendingReconcile];
        ''')
        self.assertEqual(result, ['reconcile', True, False])

    def test_user_actions_drain_before_deferred_background_events(self):
        result = self.evaluate('''
            root.run(['mode','balanced']); root.reconcileProfile();
            root.run(['preference','autoLow','true']); finish();
            const second=root.currentAction[0]; finish();
            return [second,root.currentAction[0],events];
        ''')
        self.assertEqual(result, ['preference', 'reconcile', [['mode', True], ['preference', True]]])

    def test_reconciliation_precedes_a_pending_automation_tick(self):
        result = self.evaluate('''
            root.automationEnabled=true; root.run(['status']); root.evaluateAutomation();
            root.reconcileProfile(); finish(); const first=root.currentAction[0]; finish();
            return [first,root.currentAction[0]];
        ''')
        self.assertEqual(result, ['reconcile', 'tick'])


class ReviewSafetyStructure(unittest.TestCase):
    def test_only_one_popup_window_is_created_per_sidebar(self):
        sidebar = (ROOT / 'services/StatusBar.qml').read_text()
        tray = (ROOT / 'components/AppTray.qml').read_text()
        self.assertEqual(sidebar.count('GlobalMenu {'), 1)
        self.assertNotIn('GlobalMenu {', tray)
        popup = (ROOT / 'components/GlobalMenu.qml').read_text()
        self.assertIn('visible: GlobalMenuState.isVisible', popup)
        self.assertIn('active: root.visible && root.ownsMenu', popup)

    def test_importing_media_paths_has_no_process_or_deletion_side_effects(self):
        source = (ROOT / 'components/Directories.qml').read_text()
        for text in ('execDetached', 'Component.onCompleted', 'rm -rf', 'Process {'):
            self.assertNotIn(text, source)

    def test_location_and_privacy_remain_event_driven(self):
        for path in ('globals/PrivacyState.qml', 'globals/DashboardState.qml'):
            self.assertNotIn('repeat: true', (ROOT / path).read_text())

    def test_radio_menus_no_longer_use_refresh_polling(self):
        self.assertNotIn('Timer {', (ROOT / 'components/ConnectionsTray.qml').read_text())

    def test_brightness_has_one_shared_reader(self):
        power = (ROOT / 'globals/PowerManagement.qml').read_text()
        self.assertNotIn('id: brightnessReader', power)
        self.assertIn('DisplayState.current', power)

    def test_authentication_focus_does_not_trust_cached_permission_status(self):
        power = (ROOT / 'globals/PowerManagement.qml').read_text()
        authorizing = power.split('readonly property bool authorizing:', 1)[1].split('readonly property string script:', 1)[0]
        self.assertNotIn('state.boostPasswordless', authorizing)


if __name__ == '__main__':
    unittest.main()
