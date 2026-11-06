import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, ROOT / path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


info = load('shell_info', 'bin/shell-info.py')


@unittest.skipUnless(shutil.which('node'), 'Node is needed only to run the JS unit tests')
class ShellLogicTests(unittest.TestCase):
    def evaluate(self, expression):
        script = (ROOT / 'globals/ShellUtils.js').read_text().replace('.pragma library', '')
        result = subprocess.check_output(['node', '-e', script + '\nconsole.log(JSON.stringify(' + expression + '))'], text=True)
        return json.loads(result)

    def test_warning_thresholds_are_not_triggered_early(self):
        self.assertEqual(self.evaluate('[20.1, 20, 19, 15.1, 15, 10, 5, 0, -1].map(warningBand)'), [None, 20, 20, 20, 15, 10, 5, 0, None])

    def test_warning_each_five_percent_without_duplicate_fluctuations(self):
        result = self.evaluate('(() => {let last=25; const warnings=[]; for (const p of [22,20,19,20,16,15,14,10,5,0]) { const b=warningBand(p); if (b !== null && b < last) { warnings.push(b); last=b; }} return warnings;})()')
        self.assertEqual(result, [20, 15, 10, 5, 0])

    def test_history_replaces_notification_updates(self):
        self.assertEqual(self.evaluate('mergeHistory([{key:"a",body:"old"},{key:"b"}], {key:"a",body:"new"}, 100)'), [{'key': 'a', 'body': 'new'}, {'key': 'b'}])

    def test_history_is_bounded(self):
        self.assertEqual(self.evaluate('mergeHistory(Array.from({length:100},(_,i)=>({key:String(i)})),{key:"new"},100).length'), 100)

    def test_malformed_history_is_filtered_and_fields_sanitized(self):
        result = self.evaluate('cleanHistory([null, {key:"bad"}, {key:"ok", timestamp:1, summary:"Title", body:"Body", appName:{invalid:true}}])')
        self.assertEqual(len(result), 1)
        self.assertEqual(result[0]['appName'], '')
        self.assertEqual(result[0]['summary'], 'Title')

    def test_capture_counts_multiple_clients_and_commas_in_titles(self):
        result = self.evaluate('(() => {let c={}; c=captureEvent(c,"1,window,Editor, file"); c=captureEvent(c,"1,window,Editor, file"); c=captureEvent(c,"0,window,Editor, file"); return c;})()')
        self.assertEqual(result, {'window,Editor, file': 1})

    def test_capture_stop_without_start_is_not_negative(self):
        self.assertEqual(self.evaluate('captureEvent({},"0,monitor,eDP-1")'), {})

    def test_notification_session_is_process_and_boot_scoped(self):
        stat = '123 (name with ) parentheses) ' + ' '.join(['S'] + ['0'] * 18 + ['456'] + ['0'] * 4)
        expression = 'notificationSession(' + json.dumps(stat) + ', "boot-a")'
        self.assertEqual(self.evaluate(expression), 'boot-a:123:456')
        self.assertEqual(self.evaluate(expression), self.evaluate(expression))
        self.assertNotEqual(self.evaluate(expression), self.evaluate(expression.replace('boot-a', 'boot-b')))

    def test_retained_notification_keeps_position_and_unread_timestamp_on_reload(self):
        result = self.evaluate('''(() => {
            const old = [{key:"other",timestamp:200}, {key:"boot:1:1:7",timestamp:100,body:"old"}];
            return mergeNotificationHistory(old, {key:"boot:1:1:7",timestamp:300,body:"old",replayed:true},100);
        })()''')
        self.assertEqual([entry['key'] for entry in result], ['other', 'boot:1:1:7'])
        self.assertEqual(result[1]['timestamp'], 100)
        self.assertNotIn('replayed', result[1])

    def test_notification_replacement_is_new_unread_content_not_a_reload(self):
        result = self.evaluate('mergeNotificationHistory([{key:"a",timestamp:1}],{key:"a",timestamp:2,body:"updated"},100)')
        self.assertEqual(result, [{'key': 'a', 'timestamp': 2, 'body': 'updated'}])

    def test_upgrade_migrates_retained_legacy_notification_without_duplicate(self):
        result = self.evaluate('''mergeNotificationHistory(
            [{key:"old:7",session:"1234567890",id:7,timestamp:100,appName:"App",summary:"Hi",body:"Body"}],
            {key:"boot:1:1:7",session:"boot:1:1",id:7,timestamp:200,appName:"App",summary:"Hi",body:"Body",replayed:true},100)''')
        self.assertEqual(len(result), 1)
        self.assertEqual(result[0]['timestamp'], 100)
        self.assertEqual(result[0]['session'], 'boot:1:1')

    def test_new_process_notification_id_does_not_match_old_session(self):
        result = self.evaluate('mergeNotificationHistory([{key:"old:7",session:"boot:1:1",id:7}],{key:"new:7",session:"boot:2:2",id:7,replayed:true},100)')
        self.assertEqual(len(result), 2)

    def test_notification_icons_never_fetch_remote_or_data_urls(self):
        result = self.evaluate('''["https://example.invalid/icon", "http://example.invalid/icon", "data:image/svg+xml,test",
            "file://remote-host/icon", "ftp://host/icon", "bad\\nname"].map(icon => notificationIcon(icon, name => "theme:" + name))''')
        self.assertEqual(result, [''] * 6)

    def test_notification_icons_allow_local_resources_and_theme_names(self):
        result = self.evaluate('''["/tmp/icon.png", "file:///tmp/icon.png", "qrc:/icon.png", ":/icon.png", "battery-caution"]
            .map(icon => notificationIcon(icon, name => "theme:" + name))''')
        self.assertEqual(result, ['file:///tmp/icon.png', 'file:///tmp/icon.png', 'qrc:/icon.png', ':/icon.png', 'theme:battery-caution'])


@unittest.skipUnless(shutil.which('node'), 'Node is needed for media selection tests')
class MediaSelectionTests(unittest.TestCase):
    def evaluate(self, expression):
        script = (ROOT / 'globals/MediaUtils.js').read_text().replace('.pragma library', '')
        return json.loads(subprocess.check_output(['node', '-e', script + '\nconsole.log(JSON.stringify(' + expression + '))'], text=True))

    def test_integration_is_kept_and_native_browser_duplicates_are_filtered(self):
        result = self.evaluate('''["plasma-browser-integration", "chromium.instance1", "firefox.instance2", "spotify", "playerctld"]
            .map(name => isEligible({dbusName:"org.mpris.MediaPlayer2."+name},true,true))''')
        self.assertEqual(result, [True, False, False, True, False])

    def test_native_browsers_are_kept_without_integration(self):
        self.assertTrue(self.evaluate('isEligible({dbusName:"org.mpris.MediaPlayer2.chromium.instance1"},true,false)'))

    def test_filter_can_be_disabled(self):
        self.assertTrue(self.evaluate('isEligible({dbusName:"org.mpris.MediaPlayer2.playerctld"},false,true)'))

    def test_pausing_another_player_does_not_steal_selection(self):
        self.assertEqual(self.evaluate('''(() => {const playing={name:"music",isPlaying:true}, paused={name:"browser",isPlaying:false};
            return choosePlayer([paused,playing],playing).name;})()'''), 'music')

    def test_removed_player_is_replaced_by_playing_player(self):
        self.assertEqual(self.evaluate('choosePlayer([{name:"paused",isPlaying:false},{name:"playing",isPlaying:true}],{name:"removed"}).name'), 'playing')

    def test_paused_selection_is_retained_when_nothing_is_playing(self):
        self.assertEqual(self.evaluate('''(() => {const a={name:"a",isPlaying:false}, b={name:"b",isPlaying:false};
            return choosePlayer([a,b],b).name;})()'''), 'b')

    def test_last_player_removal_clears_selection(self):
        self.assertIsNone(self.evaluate('choosePlayer([],{name:"removed"})'))


class NetworkTests(unittest.TestCase):
    def test_details_parse_ipv4_ipv6_gateway_and_dns(self):
        details = info.parse_network('GENERAL.DEVICE:wlan0\nGENERAL.CONNECTION:Office\nIP4.ADDRESS[1]:192.0.2.5/24\nIP6.ADDRESS[1]:2001:db8::1/64\nIP4.GATEWAY:192.0.2.1\nIP4.DNS[1]:192.0.2.53')
        self.assertEqual(details['interface'], 'wlan0')
        self.assertEqual(details['ipv6'], ['2001:db8::1/64'])
        self.assertEqual(details['gateway'], '192.0.2.1')
        self.assertEqual(details['dns'], ['192.0.2.53'])

    def test_invalid_interface_does_not_execute_command(self):
        with patch.object(info, 'command') as command:
            self.assertIn('error', info.network('wlan0;touch /tmp/unwanted'))
            command.assert_not_called()


@unittest.skipUnless(shutil.which('node'), 'Node is only needed for JS unit tests')
class RadioMenuTests(unittest.TestCase):
    def evaluate(self, expression):
        source = (ROOT / 'components/ConnectionsTray.qml').read_text()
        functions = []
        for name in ['connectionMenu', 'bluetoothMenu', 'isMenuChanged', 'updateWifiScannerState']:
            start = source.index('  function ' + name + '(')
            brace = source.index('{', start)
            depth = 1
            end = brace + 1
            while depth:
                if source[end] == '{': depth += 1
                elif source[end] == '}': depth -= 1
                end += 1
            functions.append(source[start:end])
        fixtures = '''
            const DeviceType = {Wifi:1, Wired:2};
            const Networking = {wifiEnabled:true, wifiHardwareEnabled:true};
            const WifiSecurityType = {Open:0,Owe:1,WpaPsk:2,Wpa2Psk:3,Sae:4};
            const allDevices = [{type:1, scannerEnabled:false, networks:{values:[]}}];
            const root = {btAdapter:{enabled:false}, requests:[], wifiRequested(network) {this.requests.push(network);}, get isPowered() {return this.btAdapter?.enabled ?? false;}};
            const btDevs = [];
            const GlobalMenuState = {isVisible:true, menuType:1};
        '''
        script = fixtures + '\n'.join(functions) + '\nconsole.log(JSON.stringify(' + expression + '))'
        return json.loads(subprocess.check_output(['node', '-e', script], text=True))

    def test_wifi_can_be_enabled_from_off_menu(self):
        self.assertEqual(self.evaluate('(() => {Networking.wifiEnabled=false; const s=connectionMenu().find(x=>x.isToggle); s.triggered(); return [s.checked,s.enabled,Networking.wifiEnabled];})()'), [False, True, True])

    def test_wifi_can_be_disabled_from_on_menu(self):
        self.assertFalse(self.evaluate('(() => {connectionMenu().find(x=>x.isToggle).triggered(); return Networking.wifiEnabled;})()'))

    def test_hardware_block_does_not_offer_a_working_toggle(self):
        self.assertEqual(self.evaluate('(() => {Networking.wifiEnabled=false; Networking.wifiHardwareEnabled=false; const s=connectionMenu().find(x=>x.isToggle); s.triggered(); return [s.enabled,Networking.wifiEnabled];})()'), [False, False])

    def test_missing_wifi_adapter_disables_toggle(self):
        self.assertFalse(self.evaluate('(() => {allDevices.length=0; return connectionMenu().find(x=>x.isToggle).enabled;})()'))

    def test_bluetooth_off_menu_can_enable_adapter(self):
        self.assertEqual(self.evaluate('(() => {const s=bluetoothMenu()[0]; s.triggered(); return [s.checked,s.enabled,root.btAdapter.enabled];})()'), [False, True, True])

    def test_missing_bluetooth_adapter_is_safe(self):
        self.assertFalse(self.evaluate('(() => {root.btAdapter=null; const s=bluetoothMenu()[0]; s.triggered(); return s.enabled;})()'))

    def test_menu_comparison_detects_switch_changes_without_text_changes(self):
        self.assertTrue(self.evaluate('isMenuChanged([{text:"Wi-Fi",checked:true}],[{text:"Wi-Fi",checked:false}])'))
        self.assertTrue(self.evaluate('isMenuChanged([{text:"Wi-Fi",enabled:true}],[{text:"Wi-Fi",enabled:false}])'))

    def test_wifi_scanning_stops_when_radio_off_or_menu_closed(self):
        self.assertEqual(self.evaluate('(() => {updateWifiScannerState(); const on=allDevices[0].scannerEnabled; Networking.wifiEnabled=false; updateWifiScannerState(); const off=allDevices[0].scannerEnabled; Networking.wifiEnabled=true; GlobalMenuState.isVisible=false; updateWifiScannerState(); return [on,off,allDevices[0].scannerEnabled];})()'), [True, False, False])

    def test_unknown_secured_sidebar_network_passes_exact_clicked_network_to_password_flow(self):
        result = self.evaluate('''(() => {
            const network={name:'New secured network',security:WifiSecurityType.Wpa2Psk,known:false,connected:false,signalStrength:.8};
            allDevices[0].networks.values=[network]; connectionMenu().find(entry=>entry.identity===network).triggered();
            return [root.requests.length,root.requests[0]===network];
        })()''')
        self.assertEqual(result, [1, True])


if __name__ == '__main__':
    unittest.main()
