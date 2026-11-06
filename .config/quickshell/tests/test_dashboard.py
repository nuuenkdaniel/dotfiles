import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('dashboard', ROOT / 'bin/dashboard.py')
dashboard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(dashboard)


class DashboardReads(unittest.TestCase):
    def test_cpu_does_not_double_count_guest_time(self):
        sample = dashboard.cpu_sample('cpu 100 20 30 400 50 6 7 8 90 10\ncpu0 1 2 3')
        self.assertEqual(sample, {'total': 621, 'idle': 450})

    def test_ram_uses_available_not_just_free(self):
        result = dashboard.memory_sample('MemTotal: 1000 kB\nMemAvailable: 400 kB\nMemFree: 100 kB\n')
        self.assertEqual(result, {'total': 1024000, 'used': 614400})

    def test_mount_list_is_local_and_excludes_container_mounts(self):
        result = dashboard.mounts('/dev/nvme0n1p2 / ext4 rw 0 0\n/dev/sda /media/My\\040Drive ext4 rw 0 0\nserver:/dir /mnt/remote nfs rw 0 0\n/dev/sda /var/lib/docker/overlay ext4 rw 0 0\nnone /proc proc rw 0 0')
        self.assertEqual(result, ['/', '/media/My Drive'])

    def test_storage_rejects_unlisted_filesystem(self):
        with patch.object(dashboard, 'mounts', return_value=['/']), patch.object(dashboard.os, 'statvfs') as stat:
            with self.assertRaises(ValueError):
                dashboard.storage('/mnt/network')
            stat.assert_not_called()

    def test_storage_uses_filesystem_allocation(self):
        class Stat:
            f_blocks = 100
            f_bfree = 25
            f_frsize = 4096
        with patch.object(dashboard, 'mounts', return_value=['/']), patch.object(dashboard.os, 'statvfs', return_value=Stat()):
            self.assertEqual(dashboard.storage('/'), {'path': '/', 'total': 409600, 'used': 307200})

    def test_coordinates_are_finite_and_in_range(self):
        for lat, lon in [('nan', '0'), ('0', 'inf'), ('91', '0'), ('0', '-181')]:
            with self.assertRaises(ValueError):
                dashboard.coordinates(lat, lon)

    def test_short_search_does_not_send_network_request(self):
        with patch.object(dashboard, 'request_json') as request:
            with self.assertRaises(ValueError):
                dashboard.search('x')
            request.assert_not_called()

    def test_geocoding_returns_explicit_selectable_locations(self):
        with patch.object(dashboard, 'request_json', return_value={'results': [{'name': 'Cambridge', 'admin1': 'England', 'country': 'United Kingdom', 'latitude': 52.2, 'longitude': .1}]}):
            self.assertEqual(dashboard.search('Cambridge')['results'][0]['name'], 'Cambridge, England, United Kingdom')

    def test_no_arbitrary_backend_command(self):
        with self.assertRaises(ValueError):
            dashboard.main(['rm', '-rf', '/'])


class WeatherCaching(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(dir='/tmp/opencode')
        self.environment = patch.dict(os.environ, {'XDG_CACHE_HOME': self.directory.name})
        self.environment.start()
        self.path = Path(self.directory.name) / 'quickshell/dashboard/weather.json'

    def tearDown(self):
        self.environment.stop()
        self.directory.cleanup()

    def cache(self, age=0, **extra):
        value = {'key': '52.00000,0.00000', 'temperature': 12.5, 'code': 0, 'isDay': True, 'fetched': time.time() - age}
        value.update(extra)
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.path.write_text(json.dumps(value))

    def test_fresh_cache_does_not_request_network(self):
        self.cache()
        with patch.object(dashboard, 'request_json') as request:
            self.assertEqual(dashboard.weather('52', '0')['temperature'], 12.5)
            request.assert_not_called()

    def test_stale_offline_weather_is_honestly_labelled(self):
        self.cache(age=1900)
        with patch.object(dashboard, 'request_json', side_effect=OSError('offline')):
            result = dashboard.weather('52', '0')
            self.assertTrue(result['stale'])
            self.assertIn('cached', result['error'])

    def test_old_location_not_shown_for_new_location(self):
        self.cache(age=1900)
        with patch.object(dashboard, 'request_json', side_effect=OSError('offline')):
            with self.assertRaises(RuntimeError):
                dashboard.weather('53', '0')

    def test_response_is_cached_in_celsius_independent_of_display_units(self):
        with patch.object(dashboard, 'request_json', return_value={'current': {'temperature_2m': 12.5, 'weather_code': 3, 'is_day': 1}}):
            result = dashboard.weather('52', '0')
            self.assertEqual(result['temperature'], 12.5)
            self.assertEqual(json.loads(self.path.read_text())['code'], 3)

    def test_malformed_cache_is_ignored(self):
        self.cache(fetched='invalid')
        with patch.object(dashboard, 'request_json', return_value={'current': {'temperature_2m': 10, 'weather_code': 0, 'is_day': 1}}):
            self.assertEqual(dashboard.weather('52', '0')['temperature'], 10)


@unittest.skipUnless(shutil.which('node'), 'Node is only needed for JS tests')
class DashboardLogic(unittest.TestCase):
    def evaluate(self, expression):
        script = (ROOT / 'globals/DashboardUtils.js').read_text().replace('.pragma library', '')
        return json.loads(subprocess.check_output(['node', '-e', script + '\nconsole.log(JSON.stringify(' + expression + '))'], text=True))

    def test_first_cpu_sample_is_not_a_fake_zero(self):
        self.assertEqual(self.evaluate('cpuUsage(null,{total:100,idle:50})'), -1)

    def test_cpu_usage_from_deltas(self):
        self.assertEqual(self.evaluate('cpuUsage({total:100,idle:50},{total:200,idle:125})'), .25)

    def test_counter_reset_is_not_a_spike(self):
        self.assertEqual(self.evaluate('cpuUsage({total:200,idle:100},{total:10,idle:5})'), -1)

    def test_calendar_is_monday_first_and_has_42_cells(self):
        result = self.evaluate('calendar(2026,10)')
        self.assertEqual(len(result), 42)
        self.assertEqual(result[0], {'day': 26, 'month': 9, 'year': 2026})
        self.assertEqual(result[6], {'day': 1, 'month': 10, 'year': 2026})

    def test_leap_year_and_year_boundary(self):
        self.assertTrue(self.evaluate('calendar(2028,1).some(d=>d.month===1 && d.day===29)'))
        self.assertTrue(self.evaluate('calendar(2026,11).some(d=>d.year===2027 && d.month===0)'))

    def test_resource_bytes_are_not_invented_when_missing(self):
        self.assertEqual(self.evaluate('bytes(undefined)'), '—')

    def test_weather_codes(self):
        self.assertEqual(self.evaluate('weather(0,false)'), ['clear_night', 'Clear'])
        self.assertEqual(self.evaluate('weather(95,true)'), ['thunderstorm', 'Thunderstorms'])


if __name__ == '__main__':
    unittest.main()
