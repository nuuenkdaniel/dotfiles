import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('locate', ROOT / 'bin/locate.py')
locate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(locate)

STANDARD_RULES = [{'priority': 0, 'src': 'all', 'table': 'local'},
                  {'priority': 32766, 'src': 'all', 'table': 'main'},
                  {'priority': 32767, 'src': 'all', 'table': 'default'}]
TAILSCALE_RULES = [
    {'priority': 5210, 'src': 'all', 'fwmark': '0x80000', 'fwmask': '0xff0000', 'table': 'main'},
    {'priority': 5230, 'src': 'all', 'fwmark': '0x80000', 'fwmask': '0xff0000', 'table': 'default'},
    {'priority': 5250, 'src': 'all', 'fwmark': '0x80000', 'fwmask': '0xff0000', 'action': 'unreachable'},
    {'priority': 5270, 'src': 'all', 'table': '52'},
]
LOCATION = {'city': 'Example City', 'region': 'Example Region', 'country_name': 'Example Country',
            'latitude': 40.0, 'longitude': -70.0, 'ip': '192.0.2.1'}


class NetworkChecks(unittest.TestCase):
    def setUp(self):
        self.environment = patch.dict(os.environ, clear=True)
        self.environment.start()
        self.nm = '802-11-wireless:wlan0\nbridge:docker0\nloopback:lo'
        self.links = [{'ifname': 'wlan0', 'link_type': 'ether', 'operstate': 'UP'}]
        self.rules = list(STANDARD_RULES)
        self.routes = [{'dst': 'default', 'dev': 'wlan0', 'gateway': '192.168.1.1'}]
        self.mesh_routes = [{'dst': '100.100.1.2/32', 'dev': 'tailscale0'}]
        self.ts = {'BackendState': 'Running'}
        self.commands = patch.object(locate, 'command', side_effect=self.command)
        self.commands.start()
        self.physical = patch.object(locate.Path, 'exists', return_value=True)
        self.physical.start()
        self.request = patch.object(locate, 'request_location', return_value=LOCATION)
        self.lookup = self.request.start()

    def tearDown(self):
        self.request.stop()
        self.physical.stop()
        self.commands.stop()
        self.environment.stop()

    def command(self, args):
        if args[0] == 'nmcli':
            return self.nm
        if args[0] == 'tailscale':
            return json.dumps(self.ts)
        if 'link' in args:
            return json.dumps(self.links)
        if 'rule' in args:
            return json.dumps(self.rules)
        if '52' in args:
            return json.dumps(self.mesh_routes if '-4' in args else [])
        return json.dumps(self.routes if '-4' in args else [])

    def mesh(self):
        self.nm += '\ntun:tailscale0'
        self.links.append({'ifname': 'tailscale0', 'link_type': 'none', 'operstate': 'UNKNOWN', 'linkinfo': {'info_kind': 'tun'}})
        self.rules += TAILSCALE_RULES

    def test_normal_network_allows_one_lookup_and_strips_ip(self):
        result = locate.detect()
        self.assertEqual(result['status'], 'detected')
        self.assertEqual(result['location']['name'], 'Example City, Example Region, Example Country')
        self.assertNotIn('ip', result['location'])
        self.lookup.assert_called_once()

    def test_networkmanager_vpn_blocks_without_request(self):
        for kind in ('vpn', 'wireguard', 'tun', 'ip-tunnel'):
            self.nm = '802-11-wireless:wlan0\n' + kind + ':vpn0'
            self.assertEqual(locate.detect()['status'], 'vpn')
        self.lookup.assert_not_called()

    def test_unmanaged_wireguard_is_also_blocked(self):
        self.links.append({'ifname': 'private0', 'link_type': 'none', 'linkinfo': {'info_kind': 'wireguard'}})
        self.assertEqual(locate.detect()['status'], 'vpn')
        self.lookup.assert_not_called()

    def test_unknown_interface_blocks_without_request(self):
        self.links.append({'ifname': 'mystery0', 'link_type': 'none'})
        self.assertEqual(locate.detect()['status'], 'uncertain')
        self.lookup.assert_not_called()

    def test_proxy_blocks_without_request(self):
        for name in ('HTTPS_PROXY', 'http_proxy', 'ALL_PROXY'):
            with patch.dict(os.environ, {name: 'http://proxy.invalid:8080'}):
                self.assertEqual(locate.detect()['status'], 'proxy')
        self.lookup.assert_not_called()

    def test_missing_network_tools_do_not_fall_back_to_network(self):
        with patch.object(locate, 'command', side_effect=FileNotFoundError()):
            self.assertEqual(locate.detect()['status'], 'unavailable')
        self.lookup.assert_not_called()

    def test_network_check_timeout_does_not_request(self):
        with patch.object(locate, 'command', side_effect=subprocess.TimeoutExpired('nmcli', 3)):
            self.assertEqual(locate.detect()['status'], 'unavailable')
        self.lookup.assert_not_called()

    def test_offline_does_not_request(self):
        self.routes = []
        self.assertEqual(locate.detect()['status'], 'offline')
        self.lookup.assert_not_called()

    def test_custom_policy_routing_blocks(self):
        self.rules.append({'priority': 100, 'src': 'all', 'table': '123'})
        self.assertEqual(locate.detect()['status'], 'uncertain')
        self.lookup.assert_not_called()

    def test_tailscale_mesh_with_private_routes_is_allowed(self):
        self.mesh()
        self.assertEqual(locate.detect()['status'], 'detected')
        self.lookup.assert_called_once()

    def test_tailscale_does_not_exempt_other_vpns(self):
        self.mesh()
        self.nm += '\nwireguard:wg0'
        self.assertEqual(locate.detect()['status'], 'vpn')
        self.lookup.assert_not_called()

    def test_tailscale_exit_node_is_blocked_even_if_offline(self):
        self.mesh()
        self.ts['ExitNodeStatus'] = {'ID': 'example', 'Online': False}
        self.assertEqual(locate.detect()['status'], 'vpn')
        self.lookup.assert_not_called()

    def test_tailscale_unknown_state_is_not_exempted(self):
        self.mesh()
        self.ts['BackendState'] = 'Starting'
        self.assertEqual(locate.detect()['status'], 'uncertain')
        self.lookup.assert_not_called()

    def test_tailscale_public_subnet_route_is_not_assumed_safe(self):
        self.mesh()
        self.mesh_routes = [{'dst': '8.0.0.0/8', 'dev': 'tailscale0'}]
        self.assertEqual(locate.detect()['status'], 'uncertain')
        self.lookup.assert_not_called()

    def test_tailscale_does_not_exempt_modified_or_unrelated_rules(self):
        self.mesh()
        self.rules.append({'priority': 123, 'src': 'all', 'table': '52'})
        self.assertEqual(locate.detect()['status'], 'uncertain')
        self.lookup.assert_not_called()

    def test_network_change_during_lookup_discards_result(self):
        with patch.object(locate, 'network_snapshot', side_effect=['first-network', 'second-network']):
            result = locate.detect()
        self.assertEqual(result['status'], 'changed')
        self.assertNotIn('location', result)

    def test_vpn_activated_during_lookup_discards_result(self):
        with patch.object(locate, 'network_snapshot', side_effect=['safe', locate.UnsafeNetwork('vpn', 'VPN detected')]):
            result = locate.detect()
        self.assertEqual(result['status'], 'vpn')
        self.assertNotIn('location', result)

    def test_provider_failure_has_no_retry_and_no_replacement_location(self):
        self.lookup.side_effect = OSError('offline')
        result = locate.detect()
        self.assertNotIn('location', result)
        self.lookup.assert_called_once()

    def test_bad_coordinates_are_not_saved(self):
        self.lookup.return_value = dict(LOCATION, latitude=float('nan'))
        self.assertNotIn('location', locate.detect())


class StartupGuard(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(dir='/tmp/opencode')
        self.environment = patch.dict(os.environ, {'XDG_RUNTIME_DIR': self.directory.name})
        self.environment.start()
        self.session = patch.object(locate, 'parent_session_key', return_value='123:456')
        self.key = self.session.start()
        self.detector = patch.object(locate, 'detect', return_value={'status': 'detected', 'message': 'Updated', 'location': LOCATION})
        self.detect = self.detector.start()

    def tearDown(self):
        self.detector.stop()
        self.session.stop()
        self.environment.stop()
        self.directory.cleanup()

    def test_hot_reload_does_not_lookup_again_or_overwrite_manual_location(self):
        self.assertIn('location', locate.startup())
        second = locate.startup()
        self.assertTrue(second['reused'])
        self.assertNotIn('location', second)
        self.detect.assert_called_once()

    def test_new_quickshell_process_gets_one_new_attempt(self):
        locate.startup()
        self.key.return_value = '123:789'
        locate.startup()
        self.key.return_value = '123:456'
        self.assertTrue(locate.startup()['reused'])
        self.assertEqual(self.detect.call_count, 2)

    def test_skipped_vpn_attempt_is_not_retried_on_reload(self):
        self.detect.return_value = {'status': 'vpn', 'message': 'VPN detected'}
        locate.startup()
        self.assertTrue(locate.startup()['reused'])
        self.detect.assert_called_once()

    def test_runtime_guard_does_not_store_location_or_ip(self):
        locate.startup()
        text = next((Path(self.directory.name) / 'quickshell-dashboard').glob('location-*.json')).read_text()
        self.assertNotIn('Example City', text)
        self.assertNotIn('latitude', text)
        self.assertNotIn('192.0.2.1', text)

    def test_missing_runtime_directory_fails_closed(self):
        with patch.dict(os.environ, {'XDG_RUNTIME_DIR': ''}):
            self.assertNotIn('location', locate.startup())
        self.detect.assert_not_called()


if __name__ == '__main__':
    unittest.main()
