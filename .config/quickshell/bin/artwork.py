#!/usr/bin/python3
"""Bounded HTTP(S) artwork downloads, without shell interpolation or partial caches."""
from pathlib import Path
import signal
import re
import stat
import subprocess
import sys
import tempfile
import time
from urllib.parse import urlsplit

MAX_BYTES = 8 * 1024 * 1024
TRANSFER_TIMEOUT = 15
MAX_CACHE_FILES = 64
MAX_CACHE_BYTES = 128 * 1024 * 1024


def prune_cache(directory, keep):
    """Bound only this downloader's files; never recurse or touch unknown entries."""
    files = []
    now = time.time()
    for path in directory.iterdir():
        try:
            info = path.lstat()
            if not stat.S_ISREG(info.st_mode) or path == keep:
                continue
            if path.name.startswith('.artwork-') and now - info.st_mtime > 3600:
                path.unlink()
            elif re.fullmatch(r'[0-9a-f]{32}', path.name):
                files.append((info.st_mtime, info.st_size, path))
        except OSError:
            continue
    total = sum(size for _, size, _ in files) + (keep.stat().st_size if keep.is_file() else 0)
    count = len(files) + 1
    for _, size, path in sorted(files):
        if count <= MAX_CACHE_FILES and total <= MAX_CACHE_BYTES:
            break
        try:
            path.unlink()
            total -= size
            count -= 1
        except OSError:
            pass


def download(url, destination):
    parsed = urlsplit(url)
    if (len(url) > 16384 or parsed.scheme not in ('http', 'https') or not parsed.hostname
            or any(ord(character) < 32 or ord(character) == 127 for character in url)):
        raise ValueError('Artwork must use an HTTP or HTTPS URL')

    destination = Path(destination)
    if destination.is_file() and 0 < destination.stat().st_size <= MAX_BYTES:
        return
    destination.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    # A same-directory temporary file makes publication atomic. Failed, timed-out,
    # and cancelled transfers never become cache hits.
    with tempfile.NamedTemporaryFile(dir=destination.parent, prefix='.artwork-', delete=False) as output:
        temporary = Path(output.name)
    try:
        result = subprocess.run([
            'curl', '--disable', '--globoff', '--silent', '--show-error', '--fail',
            '--location', '--max-redirs', '5',
            '--proto', '=http,https', '--proto-redir', '=http,https',
            '--connect-timeout', '5', '--max-time', str(TRANSFER_TIMEOUT),
            '--max-filesize', str(MAX_BYTES), '--output', str(temporary), '--', url,
        ], stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, timeout=TRANSFER_TIMEOUT + 5)
        if result.returncode != 0:
            raise RuntimeError('Artwork download failed')
        if not 0 < temporary.stat().st_size <= MAX_BYTES:
            raise ValueError('Artwork is empty or exceeds the 8 MiB limit')
        temporary.replace(destination)
        # Maintenance failure must not discard a successfully downloaded cover.
        try:
            prune_cache(destination.parent, destination)
        except OSError:
            pass
    finally:
        temporary.unlink(missing_ok=True)


def terminate(signum, frame):
    # subprocess.run kills/reaps curl when unwinding; the finally block removes
    # the temporary file when QML cancels a request. A forced kill can leave a
    # hidden temporary file, but it is never used as a completed cache entry.
    raise SystemExit(128 + signum)


if __name__ == '__main__':
    signal.signal(signal.SIGTERM, terminate)
    try:
        if len(sys.argv) != 3:
            raise ValueError('Expected artwork URL and cache destination')
        download(*sys.argv[1:])
    except Exception as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
