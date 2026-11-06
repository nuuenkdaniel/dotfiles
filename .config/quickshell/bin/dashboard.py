#!/usr/bin/python3
"""On-demand, unprivileged dashboard reads. No background service."""
import getpass
import json
import math
import os
from pathlib import Path
import re
import sys
import time
import urllib.parse
import urllib.request


def cpu_sample(text):
    # guest/guest_nice are already included in user/nice.
    values = [int(v) for v in text.splitlines()[0].split()[1:9]]
    return {'total': sum(values), 'idle': values[3] + values[4]}


def memory_sample(text):
    values = {}
    for line in text.splitlines():
        key, _, value = line.partition(':')
        values[key] = int(value.split()[0]) * 1024
    total = values['MemTotal']
    available = values.get('MemAvailable', values.get('MemFree', 0))
    return {'total': total, 'used': max(0, total - available)}


def resources():
    return {'cpu': cpu_sample(Path('/proc/stat').read_text()),
            'ram': memory_sample(Path('/proc/meminfo').read_text())}


def unescape_mount(value):
    return re.sub(r'\\([0-7]{3})', lambda m: chr(int(m[1], 8)), value)


def mounts(text=None):
    result = {'/'}
    for line in (text if text is not None else Path('/proc/self/mounts').read_text()).splitlines():
        fields = line.split()
        if len(fields) < 3:
            continue
        source, path, kind = fields[:3]
        path = unescape_mount(path)
        if source.startswith('/dev/') and kind not in ('autofs', 'fuse', 'fuse.sshfs') and not path.startswith(('/run/', '/var/lib/docker/', '/var/lib/containers/')):
            result.add(path)
    return sorted(result)


def storage(path):
    if path not in mounts():
        raise ValueError('Select an available local filesystem in Dashboard settings')
    data = os.statvfs(path)
    total = data.f_blocks * data.f_frsize
    used = (data.f_blocks - data.f_bfree) * data.f_frsize
    return {'path': path, 'total': total, 'used': used}


def identity():
    release = {}
    for line in Path('/etc/os-release').read_text().splitlines():
        key, _, value = line.partition('=')
        release[key] = value.strip('"')
    return {'user': getpass.getuser(), 'os': release.get('PRETTY_NAME', 'Linux'),
            'session': os.environ.get('XDG_CURRENT_DESKTOP') or os.environ.get('XDG_SESSION_DESKTOP') or 'Wayland',
            'uptime': float(Path('/proc/uptime').read_text().split()[0]), 'mounts': mounts(),
            'avatar': str(Path.home() / '.face') if (Path.home() / '.face').is_file() else ''}


def request_json(base, params):
    request = urllib.request.Request(base + '?' + urllib.parse.urlencode(params),
                                     headers={'User-Agent': 'Quickshell-Dashboard/1.0'})
    with urllib.request.urlopen(request, timeout=10) as response:
        return json.loads(response.read(1024 * 1024))


def search(query):
    query = query.strip()
    if not 2 <= len(query) <= 120:
        raise ValueError('Enter a city name (2–120 characters)')
    data = request_json('https://geocoding-api.open-meteo.com/v1/search',
                        {'name': query, 'count': 6, 'language': 'en', 'format': 'json'})
    return {'results': [{'name': ', '.join(filter(None, [p.get('name'), p.get('admin1'), p.get('country')])),
                         'latitude': p['latitude'], 'longitude': p['longitude']}
                        for p in data.get('results', [])]}


def coordinates(latitude, longitude):
    lat, lon = float(latitude), float(longitude)
    if not (math.isfinite(lat) and math.isfinite(lon) and -90 <= lat <= 90 and -180 <= lon <= 180):
        raise ValueError('Invalid weather location')
    return lat, lon


def weather(latitude, longitude):
    lat, lon = coordinates(latitude, longitude)
    key = f'{lat:.5f},{lon:.5f}'
    directory = Path(os.environ.get('XDG_CACHE_HOME', str(Path.home() / '.cache'))) / 'quickshell/dashboard'
    path = directory / 'weather.json'
    cached = {}
    try:
        cached = json.loads(path.read_text())
        if (not isinstance(cached, dict) or cached.get('key') != key
                or not isinstance(cached.get('fetched'), (float, int))
                or not isinstance(cached.get('temperature'), (float, int))
                or not math.isfinite(cached['temperature'])
                or not isinstance(cached.get('code'), int)):
            cached = {}
    except (OSError, ValueError):
        pass
    age = time.time() - cached.get('fetched', 0)
    if cached and 0 <= age < 1800:
        return cached
    try:
        data = request_json('https://api.open-meteo.com/v1/forecast', {
            'latitude': lat, 'longitude': lon,
            'current': 'temperature_2m,weather_code,is_day', 'timezone': 'auto', 'forecast_days': 1})
        current = data['current']
        temperature = float(current['temperature_2m'])
        if not math.isfinite(temperature):
            raise ValueError('Invalid temperature')
        result = {'key': key, 'temperature': temperature, 'code': int(current['weather_code']),
                  'isDay': bool(current['is_day']), 'fetched': time.time()}
        # Caching failure must not discard a valid weather response.
        try:
            directory.mkdir(mode=0o700, parents=True, exist_ok=True)
            temp = directory / f'weather-{os.getpid()}.tmp'
            temp.write_text(json.dumps(result))
            temp.replace(path)
        except OSError:
            pass
        return result
    except Exception:
        if cached:
            return dict(cached, stale=True, error='Offline · showing cached weather')
        raise RuntimeError('Weather unavailable. Check your connection and try reopening the dashboard.') from None


def main(args):
    if args == ['resources']:
        return resources()
    if args == ['identity']:
        return identity()
    if len(args) == 2 and args[0] == 'storage':
        return storage(args[1])
    if len(args) == 2 and args[0] == 'search':
        return search(args[1])
    if len(args) == 3 and args[0] == 'weather':
        return weather(*args[1:])
    raise ValueError('Invalid dashboard request')


if __name__ == '__main__':
    try:
        print(json.dumps(main(sys.argv[1:])))
    except Exception as error:
        print(json.dumps({'error': str(error)}))
