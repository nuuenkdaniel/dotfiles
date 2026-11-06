import importlib.util
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import threading
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('artwork', ROOT / 'bin/artwork.py')
artwork = importlib.util.module_from_spec(spec)
spec.loader.exec_module(artwork)


class ArtworkDownloads(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(dir='/tmp/opencode')
        self.addCleanup(self.directory.cleanup)
        self.destination = Path(self.directory.name) / "cache with ' quotes" / 'cover'

    def transfer(self, command, **kwargs):
        self.assertEqual(command[:2], ['curl', '--disable'])
        self.assertIn('--globoff', command)
        for option in ('--proto', '--proto-redir'):
            self.assertEqual(command[command.index(option) + 1], '=http,https')
        self.assertEqual(command[command.index('--max-filesize') + 1], str(artwork.MAX_BYTES))
        self.assertEqual(command[command.index('--max-time') + 1], str(artwork.TRANSFER_TIMEOUT))
        self.assertEqual(command[command.index('--connect-timeout') + 1], '5')
        self.assertEqual(command[command.index('--max-redirs') + 1], '5')
        self.assertIn('--fail', command)
        self.assertNotIn('shell', kwargs)
        self.assertEqual(kwargs['timeout'], artwork.TRANSFER_TIMEOUT + 5)
        self.temporary = Path(command[command.index('--output') + 1])
        self.assertEqual(self.temporary.parent, self.destination.parent)
        self.temporary.write_bytes(b'artwork bytes')
        return subprocess.CompletedProcess(command, 0)

    def test_shell_characters_are_a_single_literal_argument(self):
        url = "https://example.invalid/cover'; $(touch SHOULD_NOT_EXIST); #{}.png"
        with patch.object(artwork.subprocess, 'run', side_effect=self.transfer) as run:
            artwork.download(url, self.destination)
        self.assertEqual(run.call_args.args[0][-2:], ['--', url])
        self.assertEqual(self.destination.read_bytes(), b'artwork bytes')
        self.assertFalse(self.temporary.exists())

    def test_invalid_schemes_and_urls_never_execute_a_downloader(self):
        with patch.object(artwork.subprocess, 'run') as run:
            for url in ('file:///etc/passwd', 'ftp://example.invalid/art', 'data:image/png,x',
                        '--output=somewhere', 'https:///missing-host', 'https://example.invalid/\nheader',
                        'https://example.invalid/' + 'x' * 16384):
                with self.subTest(url=url[:80]), self.assertRaises(ValueError):
                    artwork.download(url, self.destination)
            run.assert_not_called()
        self.assertFalse(self.destination.parent.exists())

    def test_valid_cache_does_not_download(self):
        self.destination.parent.mkdir()
        self.destination.write_bytes(b'cached art')
        with patch.object(artwork.subprocess, 'run') as run:
            artwork.download('https://example.invalid/art', self.destination)
            run.assert_not_called()

    def test_empty_cache_is_replaced(self):
        self.destination.parent.mkdir()
        self.destination.touch()
        with patch.object(artwork.subprocess, 'run', side_effect=self.transfer):
            artwork.download('https://example.invalid/art', self.destination)
        self.assertEqual(self.destination.read_bytes(), b'artwork bytes')

    def test_failure_timeout_and_cancellation_do_not_publish_partial_files(self):
        for failure in (RuntimeError('failed'), subprocess.TimeoutExpired('curl', 20), SystemExit(143)):
            with self.subTest(failure=type(failure).__name__):
                def transfer(command, **kwargs):
                    self.transfer(command, **kwargs)
                    raise failure
                with patch.object(artwork.subprocess, 'run', side_effect=transfer):
                    with self.assertRaises(type(failure)):
                        artwork.download('https://example.invalid/art', self.destination)
                self.assertFalse(self.destination.exists())
                self.assertEqual(list(self.destination.parent.iterdir()), [])

    def test_nonzero_curl_exit_does_not_cache_error_page(self):
        def transfer(command, **kwargs):
            self.transfer(command, **kwargs)
            return subprocess.CompletedProcess(command, 22)
        with patch.object(artwork.subprocess, 'run', side_effect=transfer):
            with self.assertRaises(RuntimeError):
                artwork.download('https://example.invalid/art', self.destination)
        self.assertEqual(list(self.destination.parent.iterdir()), [])

    def test_empty_or_oversized_response_is_not_published(self):
        for size in (0, artwork.MAX_BYTES + 1):
            with self.subTest(size=size):
                def transfer(command, **kwargs):
                    result = self.transfer(command, **kwargs)
                    with self.temporary.open('wb') as output:
                        output.truncate(size)
                    return result
                with patch.object(artwork.subprocess, 'run', side_effect=transfer):
                    with self.assertRaises(ValueError):
                        artwork.download('https://example.invalid/art', self.destination)
                self.assertFalse(self.destination.exists())
                self.assertEqual(list(self.destination.parent.iterdir()), [])

    def test_cache_is_not_replaced_before_transfer_finishes(self):
        self.destination.parent.mkdir()
        self.destination.touch()
        def transfer(command, **kwargs):
            result = self.transfer(command, **kwargs)
            self.assertEqual(self.destination.read_bytes(), b'')
            return result
        with patch.object(artwork.subprocess, 'run', side_effect=transfer):
            artwork.download('https://example.invalid/art', self.destination)
        self.assertEqual(self.destination.read_bytes(), b'artwork bytes')

    def test_bounded_cache_pruning_preserves_unrelated_files_and_symlinks(self):
        directory = self.destination.parent
        directory.mkdir()
        keep = directory / ('a' * 32)
        keep.write_bytes(b'current')
        for index in range(5):
            (directory / f'{index:032x}').write_bytes(b'cached')
        unrelated = directory / 'my-image.png'
        unrelated.write_bytes(b'untouched')
        link = directory / ('b' * 32)
        link.symlink_to(unrelated)
        with patch.object(artwork, 'MAX_CACHE_FILES', 2):
            artwork.prune_cache(directory, keep)
        self.assertTrue(keep.is_file())
        self.assertEqual(unrelated.read_bytes(), b'untouched')
        self.assertTrue(link.is_symlink())
        self.assertEqual(len([path for path in directory.iterdir() if len(path.name) == 32 and not path.is_symlink()]), 2)


@unittest.skipUnless(shutil.which('curl'), 'curl is needed for local HTTP integration tests')
class ArtworkHttpIntegration(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.requests = []
        cls.slowStarted = threading.Event()
        cls.releaseSlow = threading.Event()
        class Handler(BaseHTTPRequestHandler):
            def do_GET(self):
                cls.requests.append(self.path)
                if self.path in ('/redirect', '/unsafe'):
                    self.send_response(302)
                    self.send_header('Location', '/image' if self.path == '/redirect' else 'file:///etc/passwd')
                    self.end_headers()
                    return
                self.send_response(200)
                self.end_headers()
                if self.path == '/slow':
                    cls.slowStarted.set()
                    cls.releaseSlow.wait(10)
                    return
                self.wfile.write(b'x' * 129 if self.path == '/oversize' else b'local artwork')

            def log_message(self, *args):
                pass
        cls.server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()
        cls.base = 'http://127.0.0.1:' + str(cls.server.server_port)

    @classmethod
    def tearDownClass(cls):
        cls.releaseSlow.set()
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join(timeout=3)

    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(dir='/tmp/opencode')
        self.addCleanup(self.directory.cleanup)
        self.destination = Path(self.directory.name) / 'cover'
        environment = patch.dict(os.environ, {'NO_PROXY': '127.0.0.1', 'no_proxy': '127.0.0.1'})
        environment.start()
        self.addCleanup(environment.stop)

    def test_http_redirect_downloads_atomically(self):
        artwork.download(self.base + '/redirect', self.destination)
        self.assertEqual(self.destination.read_bytes(), b'local artwork')
        self.assertEqual(list(self.destination.parent.iterdir()), [self.destination])

    def test_apostrophe_and_shell_syntax_reach_server_literally(self):
        path = "/cover';$(echo_not_a_command);.png"
        artwork.download(self.base + path, self.destination)
        self.assertIn(path, self.requests)
        self.assertEqual(self.destination.read_bytes(), b'local artwork')

    def test_redirect_to_local_file_is_blocked(self):
        with self.assertRaises(RuntimeError):
            artwork.download(self.base + '/unsafe', self.destination)
        self.assertEqual(list(self.destination.parent.iterdir()), [])

    def test_unknown_length_response_is_bounded_by_curl(self):
        with patch.object(artwork, 'MAX_BYTES', 64), self.assertRaises(RuntimeError):
            artwork.download(self.base + '/oversize', self.destination)
        self.assertEqual(list(self.destination.parent.iterdir()), [])

    def test_cancellation_reaps_downloader_and_removes_temporary_file(self):
        with subprocess.Popen(['python3', '-B', str(ROOT / 'bin/artwork.py'),
                               self.base + '/slow', str(self.destination)],
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE) as process:
            try:
                self.assertTrue(self.slowStarted.wait(5), 'Local request did not start')
                process.terminate()
                process.communicate(timeout=5)
                self.assertEqual(process.returncode, 143)
                self.assertEqual(list(self.destination.parent.iterdir()), [])
            finally:
                self.releaseSlow.set()
                if process.poll() is None:
                    process.kill()
                    process.communicate(timeout=5)


@unittest.skipUnless(shutil.which('node'), 'Node is needed for player request lifecycle tests')
class ArtworkRequestLifecycle(unittest.TestCase):
    def evaluate(self, expression):
        source = (ROOT / 'widgets/PlayerControls.qml').read_text()
        functions = []
        for name in ('refreshArtwork', 'startArtwork', 'finishArtwork'):
            start = source.index('  function ' + name + '(')
            brace = source.index('{', start)
            depth, end = 1, brace + 1
            while depth:
                if source[end] == '{': depth += 1
                elif source[end] == '}': depth -= 1
                end += 1
            functions.append(source[start:end])
        fixtures = '''
            const tasks = [];
            const Qt = {callLater: f => tasks.push(f), resolvedUrl: () => 'file:///test/artwork.py'};
            const root = {artUrl:'https://example.invalid/A', artFilePath:'/cache/A',
                downloaded:false, artworkPending:false, isLocalArt:false, isDataUri:false, presentationActive:true};
            let running = false;
            const coverArtDownloader = {targetFile:'', artFilePath:'', command:[],
                get running() {return running;}, set running(value) {if (value) running=true;}};
            function flush() {while (tasks.length) tasks.shift()();}
            function exit(code) {running=false; root.finishArtwork(code); flush();}
        '''
        bindings = '\n'.join('root.' + name + '=' + name + ';' for name in ('refreshArtwork', 'startArtwork', 'finishArtwork'))
        script = fixtures + '\n'.join(functions) + bindings + '\nconsole.log(JSON.stringify((() => {' + expression + '})()))'
        return json.loads(subprocess.check_output(['node', '-e', script], text=True))

    def test_success_marks_only_the_current_request_downloaded(self):
        self.assertEqual(self.evaluate('root.refreshArtwork(); flush(); exit(0); return [root.downloaded, running, coverArtDownloader.command];'),
                         [True, False, ['python3', '/test/artwork.py', 'https://example.invalid/A', '/cache/A']])

    def test_hidden_player_defers_artwork_until_presented(self):
        self.assertEqual(self.evaluate('''
            root.presentationActive=false; root.refreshArtwork(); flush();
            const hidden = [running, root.artworkPending];
            root.presentationActive=true; root.startArtwork();
            return [hidden, running];
        '''), [[False, True], True])

    def test_track_switch_keeps_old_identity_until_exit_and_starts_latest(self):
        self.assertEqual(self.evaluate('''
            root.refreshArtwork(); flush();
            root.artUrl='https://example.invalid/B'; root.artFilePath='/cache/B'; root.refreshArtwork();
            const old = coverArtDownloader.targetFile;
            root.artUrl='https://example.invalid/C'; root.artFilePath='/cache/C'; root.refreshArtwork();
            exit(0);
            return [old, root.downloaded, running, coverArtDownloader.targetFile];
        '''), ['https://example.invalid/A', False, True, 'https://example.invalid/C'])

    def test_switching_away_then_back_restarts_cancelled_request(self):
        self.assertEqual(self.evaluate('''
            root.refreshArtwork(); flush();
            root.artUrl='https://example.invalid/B'; root.artFilePath='/cache/B'; root.refreshArtwork();
            root.artUrl='https://example.invalid/A'; root.artFilePath='/cache/A'; root.refreshArtwork();
            exit(143);
            return [root.downloaded, running, coverArtDownloader.targetFile];
        '''), [False, True, 'https://example.invalid/A'])

    def test_local_data_and_empty_art_do_not_start_a_downloader(self):
        for url, local, data in [('file:///cover.png', True, False), ('data:image/png,x', False, True), ('', False, False)]:
            with self.subTest(url=url):
                self.assertEqual(self.evaluate('root.artUrl=' + json.dumps(url) + ';root.isLocalArt=' + json.dumps(local)
                    + ';root.isDataUri=' + json.dumps(data) + ';root.refreshArtwork(); flush(); return running;'), False)

    def test_switch_to_local_art_does_not_accept_old_remote_completion(self):
        self.assertEqual(self.evaluate('''
            root.refreshArtwork(); flush();
            root.artUrl='file:///cover.png'; root.artFilePath='/cache/local'; root.isLocalArt=true; root.refreshArtwork();
            exit(0);
            return [root.downloaded, running];
        '''), [False, False])


if __name__ == '__main__':
    unittest.main()
