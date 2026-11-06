import json
from pathlib import Path
import shutil
import subprocess
import unittest

from test_service_logic import qml_functions

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(shutil.which('node'), 'Node is needed for Wi-Fi workflow tests')
class WifiPasswordWorkflow(unittest.TestCase):
    def evaluate(self, expression):
        names = ['isPasswordNetwork', 'wifiAvailable', 'cancelPassword', 'clearUnavailableWifi',
                 'focusWifiPassword', 'requestWifiConnection', 'connectPassword',
                 'wifiConnectionFailed', 'wifiConnected']
        functions = qml_functions('components/ConnectivitySettings.qml', names)
        bindings = '\n'.join('root.' + name + '=' + name + ';' for name in names)
        fixtures = '''
            const tasks=[], calls=[];
            const Qt={callLater:fn => tasks.push(fn)};
            function flush() {while(tasks.length) tasks.shift()();}
            const WifiSecurityType={Open:0,Owe:1,WpaPsk:2,Wpa2Psk:3,Sae:4,Wpa2Eap:5};
            const ConnectionFailReason={NoSecrets:1,WifiAuthTimeout:2,WifiNetworkLost:3,toString:reason => 'reason '+reason};
            const Networking={wifiEnabled:true,wifiHardwareEnabled:true};
            const password={text:'',focusCount:0,forceActiveFocus() {this.focusCount++;}};
            const root={active:true,bluetooth:false,passwordNetwork:null,attemptedNetwork:null,
                networks:[],errorMessage:''};
            const network={name:'Test Network',security:WifiSecurityType.Wpa2Psk,known:false,
                connected:false,stateChanging:false,connect() {calls.push(['connect']);},
                connectWithPsk(secret) {calls.push(['psk',secret,password.text,root.passwordNetwork]);}};
            root.networks=[network];
        '''
        script = fixtures + '\nwith(root) {\n' + functions + '\n' + bindings + '\n}\nconsole.log(JSON.stringify((() => {' + expression + '})()))'
        return json.loads(subprocess.check_output(['node', '-e', script], text=True))

    def test_new_wpa_wpa2_and_wpa3_personal_networks_prompt_without_attempting_empty_password(self):
        for security in ('WpaPsk', 'Wpa2Psk', 'Sae'):
            with self.subTest(security=security):
                result = self.evaluate('network.security=WifiSecurityType.' + security + ''';
                    root.requestWifiConnection(network); flush();
                    return [root.passwordNetwork===network,password.focusCount,calls.length];''')
                self.assertEqual(result, [True, 1, 0])

    def test_password_is_passed_natively_and_input_is_cleared_before_backend_call(self):
        result = self.evaluate('''
            root.requestWifiConnection(network); password.text="not-a-real-password"; root.connectPassword();
            return [calls,password.text,root.passwordNetwork,root.attemptedNetwork===network];
        ''')
        self.assertEqual(result, [[['psk', 'not-a-real-password', '', None]], '', None, True])

    def test_saved_and_open_networks_use_normal_connection(self):
        for setup in ('network.known=true;', 'network.security=WifiSecurityType.Open;', 'network.security=WifiSecurityType.Owe;'):
            with self.subTest(setup=setup):
                result = self.evaluate(setup + 'root.requestWifiConnection(network); return [calls,root.passwordNetwork];')
                self.assertEqual(result, [[['connect']], None])

    def test_missing_saved_secret_prompts_for_password(self):
        result = self.evaluate('''
            network.known=true; root.requestWifiConnection(network);
            root.wifiConnectionFailed(network,ConnectionFailReason.NoSecrets); flush();
            return [calls,root.passwordNetwork===network,password.focusCount,root.errorMessage.length>0];
        ''')
        self.assertEqual(result, [[['connect']], True, 1, True])

    def test_synchronous_wrong_password_failure_keeps_retry_prompt(self):
        result = self.evaluate('''
            network.connectWithPsk=function() {root.wifiConnectionFailed(network,ConnectionFailReason.NoSecrets);};
            root.requestWifiConnection(network); password.text='wrong-password'; root.connectPassword(); flush();
            return [root.passwordNetwork===network,password.text,root.errorMessage.length>0];
        ''')
        self.assertEqual(result, [True, '', True])

    def test_authentication_timeout_can_be_retried(self):
        result = self.evaluate('''
            root.requestWifiConnection(network); password.text='not-a-real-password'; root.connectPassword();
            root.wifiConnectionFailed(network,ConnectionFailReason.WifiAuthTimeout);
            return [root.passwordNetwork===network,password.text];
        ''')
        self.assertEqual(result, [True, ''])

    def test_enterprise_network_is_not_given_a_personal_network_psk(self):
        result = self.evaluate('''
            network.security=WifiSecurityType.Wpa2Eap; root.requestWifiConnection(network);
            return [root.passwordNetwork,calls.length,root.errorMessage.includes('enterprise')];
        ''')
        self.assertEqual(result, [None, 0, True])

    def test_radio_off_or_hardware_block_prevents_connection(self):
        for flag in ('wifiEnabled', 'wifiHardwareEnabled'):
            with self.subTest(flag=flag):
                result = self.evaluate('Networking.' + flag + '=false; root.requestWifiConnection(network); return [root.passwordNetwork,calls.length,!!root.errorMessage];')
                self.assertEqual(result, [None, 0, True])

    def test_disappearing_network_clears_secret_and_cannot_be_submitted(self):
        result = self.evaluate('''
            root.requestWifiConnection(network); password.text='not-a-real-password'; root.networks=[];
            root.connectPassword(); return [password.text,root.passwordNetwork,calls.length];
        ''')
        self.assertEqual(result, ['', None, 0])

    def test_cancel_clears_secret_and_deferred_focus_does_not_reopen_prompt(self):
        result = self.evaluate('''
            root.requestWifiConnection(network); password.text='not-a-real-password'; root.cancelPassword(); flush();
            root.connectPassword(); return [password.text,root.passwordNetwork,password.focusCount,calls.length];
        ''')
        self.assertEqual(result, ['', None, 0, 0])

    def test_repeated_submission_while_connecting_does_nothing(self):
        result = self.evaluate('''
            root.requestWifiConnection(network); password.text='not-a-real-password'; network.stateChanging=true;
            root.connectPassword(); return calls.length;
        ''')
        self.assertEqual(result, 0)

    def test_other_network_failure_does_not_replace_selected_network(self):
        result = self.evaluate('''
            root.requestWifiConnection(network);
            root.wifiConnectionFailed({name:'Other'},ConnectionFailReason.NoSecrets);
            return [root.passwordNetwork===network,root.errorMessage];
        ''')
        self.assertEqual(result, [True, ''])

    def test_success_clears_prompt_and_previous_error(self):
        result = self.evaluate('''
            root.requestWifiConnection(network); root.errorMessage='Old failure'; network.connected=true;
            root.wifiConnected(network); return [root.passwordNetwork,root.attemptedNetwork,root.errorMessage];
        ''')
        self.assertEqual(result, [None, None, ''])


@unittest.skipUnless(shutil.which('node'), 'Node is needed for lazy Wi-Fi handoff tests')
class SidebarWifiHandoff(unittest.TestCase):
    def evaluate(self, expression):
        functions = qml_functions('components/SettingsMenu.qml', ['openWifi', 'deliverWifiRequest'])
        fixtures = '''
            const tasks=[], requests=[];
            const Qt={callLater:fn => tasks.push(fn)};
            function flush() {while(tasks.length) tasks.shift()();}
            const root={visible:false,activeTab:'Audio',pendingWifiNetwork:null};
            const connectivityPage={item:null};
            const page={requestWifiConnection:network => requests.push(network)};
            const first={name:'First'}, second={name:'Second'};
        '''
        script = fixtures + '\nwith(root) {\n' + functions + '''
            root.openWifi=openWifi; root.deliverWifiRequest=deliverWifiRequest;
        } console.log(JSON.stringify((() => {''' + expression + '})()))'
        return json.loads(subprocess.check_output(['node', '-e', script], text=True))

    def test_clicked_network_is_delivered_once_after_lazy_page_load(self):
        result = self.evaluate('''
            root.openWifi(first); flush(); const pending=root.pendingWifiNetwork===first;
            connectivityPage.item=page; root.deliverWifiRequest(); root.deliverWifiRequest();
            return [root.visible,root.activeTab,pending,requests.map(n=>n.name),root.pendingWifiNetwork];
        ''')
        self.assertEqual(result, [True, 'Wi-Fi', True, ['First'], None])

    def test_latest_request_wins_before_page_is_ready(self):
        result = self.evaluate('''
            root.openWifi(first); root.openWifi(second); connectivityPage.item=page; flush();
            return requests.map(n=>n.name);
        ''')
        self.assertEqual(result, ['Second'])

    def test_closed_or_switched_page_discards_pending_request(self):
        for steering in ('root.visible=false;', "root.activeTab='Bluetooth';"):
            with self.subTest(steering=steering):
                result = self.evaluate('root.openWifi(first); connectivityPage.item=page;' + steering + 'flush(); return [requests.length,root.pendingWifiNetwork];')
                self.assertEqual(result, [0, None])


if __name__ == '__main__':
    unittest.main()
