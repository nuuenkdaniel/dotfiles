#!/usr/bin/python3
"""One startup IP-location lookup, only after conservative local VPN checks."""
import fcntl
import hashlib
import ipaddress
import json
import math
import os
from pathlib import Path
import re
import subprocess
import urllib.request


class UnsafeNetwork(Exception):
    def __init__(self, status, message):
        self.status = status
        super().__init__(message)


def command(args):
    return subprocess.run(args, check=True, capture_output=True, text=True,
                          timeout=3, env=dict(os.environ, LC_ALL='C')).stdout.strip()


def json_command(args):
    result = json.loads(command(args))
    if not isinstance(result, list) or not all(isinstance(item, dict) for item in result):
        raise ValueError('Unexpected network status')
    return result


def tailscale_is_mesh_only():
    data = json.loads(command(['tailscale', 'status', '--json', '--peers=false']))
    if not isinstance(data, dict) or data.get('BackendState') != 'Running':
        raise UnsafeNetwork('uncertain', 'Tailscale status uncertain; saved location kept.')
    if data.get('ExitNodeStatus'):
        raise UnsafeNetwork('vpn', 'Tailscale exit node selected; saved location kept.')
    return True


def safe_rule(rule, tailscale_mesh):
    rule = {key: value for key, value in rule.items() if key != 'protocol'}
    if 'table' in rule:
        rule['table'] = {'255': 'local', '254': 'main', '253': 'default'}.get(str(rule['table']), str(rule['table']))
    if rule in [{'priority': p, 'src': 'all', 'table': table}
                for p, table in ((0, 'local'), (32766, 'main'), (32767, 'default'))]:
        return True
    # Only exempt the exact Tailscale rules, not arbitrary policy routing.
    if not tailscale_mesh:
        return False
    if rule == {'priority': 5270, 'src': 'all', 'table': '52'}:
        return True
    if rule.get('fwmark') != '0x80000' or rule.get('fwmask') != '0xff0000':
        return False
    base = {'src': 'all', 'fwmark': '0x80000', 'fwmask': '0xff0000'}
    return rule in [dict(base, priority=5210, table='main'), dict(base, priority=5230, table='default'),
                    dict(base, priority=5250, action='unreachable')]


def check_tailscale_routes(family):
    for route in json_command(['ip', family, '-j', 'route', 'show', 'table', '52']):
        destination = ipaddress.ip_network(route.get('dst', ''), strict=False)
        cgnat = ipaddress.ip_network('100.64.0.0/10')
        if (route.get('dev') != 'tailscale0' or destination.prefixlen == 0
                or not (destination.is_private or (destination.version == 4 and destination.subnet_of(cgnat)))):
            raise UnsafeNetwork('uncertain', 'Tailscale has non-mesh routes; saved location kept.')


def network_snapshot():
    # Do not bypass configured proxies to obtain a location behind the user's back.
    if any(value and key.lower() in ('http_proxy', 'https_proxy', 'all_proxy')
           for key, value in os.environ.items()):
        raise UnsafeNetwork('proxy', 'Proxy configured; saved location kept.')
    connections = command(['nmcli', '-t', '-f', 'TYPE,DEVICE', 'connection', 'show', '--active']).splitlines()
    types = set()
    tailscale_mesh = False
    for line in connections:
        kind, separator, device = line.partition(':')
        if not separator or not device:
            raise ValueError('Unknown connection device')
        if kind == 'tun' and device == 'tailscale0':
            tailscale_mesh = tailscale_is_mesh_only()
        else:
            types.add(kind)
    if types & {'vpn', 'wireguard', 'tun', 'ip-tunnel', 'ppp', 'pppoe'}:
        raise UnsafeNetwork('vpn', 'VPN/tunnel detected; saved location kept.')
    if not types or types - {'802-11-wireless', '802-3-ethernet', 'wifi', 'ethernet', 'bridge', 'veth', 'loopback'}:
        raise UnsafeNetwork('uncertain', 'Network type could not be verified; saved location kept.')
    links = json_command(['ip', '-j', '-details', 'link', 'show', 'up'])
    active = {}
    for link in links:
        name = link['ifname']
        kind = link.get('linkinfo', {}).get('info_kind', '')
        if name == 'tailscale0' and kind == 'tun':
            if not tailscale_mesh:
                tailscale_mesh = tailscale_is_mesh_only()
            active[name] = (kind, link.get('operstate'))
            continue
        if re.match(r'^(tun|tap|wg|tailscale|zt|vpn|ppp|ipsec|proton|mullvad|nord|warp)', name, re.I) or kind in {
                'tun', 'tap', 'wireguard', 'xfrm', 'vti', 'vti6', 'gre', 'gretap', 'ip6gre', 'ip6gretap', 'ipip', 'sit', 'ip6tnl'}:
            raise UnsafeNetwork('vpn', 'VPN/tunnel detected; saved location kept.')
        if kind not in ('', 'bridge', 'veth') or link.get('link_type') not in ('ether', 'loopback'):
            raise UnsafeNetwork('uncertain', 'Unrecognized network interface; saved location kept.')
        active[name] = (kind, link.get('operstate'))
    routes = []
    rules = []
    for family in ('-4', '-6'):
        family_rules = json_command(['ip', family, '-j', 'rule', 'show'])
        for rule in family_rules:
            if not safe_rule(rule, tailscale_mesh):
                raise UnsafeNetwork('uncertain', 'Custom routing detected; saved location kept.')
        rules.append(family_rules)
        if tailscale_mesh:
            check_tailscale_routes(family)
        for route in json_command(['ip', family, '-j', 'route', 'show', 'default']):
            name = route.get('dev', '')
            if (name not in active or active[name][0] or 'linkdown' in route.get('flags', [])
                    or not (Path('/sys/class/net') / name / 'device').exists()):
                raise UnsafeNetwork('uncertain', 'Internet route could not be verified; saved location kept.')
            # Ignore changing IPv6 route lifetimes, but detect gateway/device changes.
            routes.append((family, name, route.get('gateway'), route.get('prefsrc'), route.get('metric')))
    if not routes:
        raise UnsafeNetwork('offline', 'No internet route; saved location kept.')
    return sorted(types), sorted(active.items()), rules, sorted(routes, key=str)


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def request_location():
    # Exactly one provider, no redirects, fallback providers, IP logs or retries.
    request = urllib.request.Request('https://ipapi.co/json/',
                                     headers={'User-Agent': 'Quickshell-Dashboard/1.0'})
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())
    with opener.open(request, timeout=8) as response:
        return json.loads(response.read(65536))


def detect():
    try:
        before = network_snapshot()
        data = request_location()
        if not isinstance(data, dict) or data.get('error') or not isinstance(data.get('city'), str) or not data['city'].strip():
            raise ValueError('Location unavailable')
        if isinstance(data.get('latitude'), bool) or isinstance(data.get('longitude'), bool):
            raise ValueError('Invalid coordinates')
        lat, lon = float(data['latitude']), float(data['longitude'])
        if not (math.isfinite(lat) and math.isfinite(lon) and -90 <= lat <= 90 and -180 <= lon <= 180):
            raise ValueError('Invalid coordinates')
        # A VPN or network change during the request must not overwrite the cache.
        if network_snapshot() != before:
            return {'status': 'changed', 'message': 'Network changed during lookup; saved location kept.'}
        name = ', '.join(dict.fromkeys(value.strip()[:120] for value in
                         (data['city'], data.get('region'), data.get('country_name')) if isinstance(value, str) and value.strip()))
        return {'status': 'detected', 'message': 'Location updated from public IP (ipapi.co).',
                'location': {'name': name, 'latitude': lat, 'longitude': lon}}
    except UnsafeNetwork as error:
        return {'status': error.status, 'message': str(error)}
    except (OSError, subprocess.SubprocessError, ValueError, KeyError, TypeError, AttributeError):
        return {'status': 'unavailable', 'message': 'Location/network check unavailable; saved location kept.'}


def parent_session_key():
    pid = os.getppid()
    # Include process start ticks to prevent PID reuse from suppressing a new session.
    ticks = Path(f'/proc/{pid}/stat').read_text().rsplit(')', 1)[1].split()[19]
    return f'{pid}:{ticks}'


def startup():
    # Keep this guard in the runtime directory, not the shell config: hot reloads
    # must not cause more location requests. Mark the attempt before any network I/O.
    try:
        runtime = os.environ.get('XDG_RUNTIME_DIR')
        if not runtime:
            raise OSError('No runtime directory')
        directory = Path(runtime) / 'quickshell-dashboard'
        directory.mkdir(mode=0o700, parents=True, exist_ok=True)
        key = parent_session_key()
        path = directory / ('location-' + hashlib.sha256(key.encode()).hexdigest()[:20] + '.json')
        with os.fdopen(os.open(path, os.O_RDWR | os.O_CREAT, 0o600), 'r+') as guard:
            try:
                fcntl.flock(guard, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                return {'status': 'already-checked', 'message': 'Startup location check already in progress.'}
            try:
                previous = json.load(guard)
            except ValueError:
                previous = {}
            if isinstance(previous, dict) and previous.get('session') == key:
                return {'status': previous.get('status', 'already-checked'),
                        'message': previous.get('message', 'Already checked this Quickshell session; saved location kept.'), 'reused': True}

            def save(result):
                guard.seek(0)
                guard.truncate()
                json.dump(dict(session=key, status=result['status'], message=result['message']), guard)
                guard.flush()

            save({'status': 'already-checked', 'message': 'Already attempted this Quickshell session; saved location kept.'})
            result = detect()
            save(result)  # No location or IP is stored in the runtime guard.
            return result
    except (OSError, ValueError, IndexError):
        return {'status': 'unavailable', 'message': 'Startup guard unavailable; saved location kept.'}


if __name__ == '__main__':
    print(json.dumps(startup()))
