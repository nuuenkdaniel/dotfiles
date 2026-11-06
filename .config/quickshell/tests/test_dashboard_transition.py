import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
QT6_RUNNER = next((str(path) for path in [Path('/usr/lib/qt6/bin/qmltestrunner'), Path('/usr/lib64/qt6/bin/qmltestrunner')]
                   if path.is_file()), None) or shutil.which('qmltestrunner6') or shutil.which('qmltestrunner')


@unittest.skipUnless(QT6_RUNNER, 'Qt 6 Quick Test is needed for animation tests')
class DashboardTransitionTests(unittest.TestCase):
    def run_qml(self, directory):
        result = subprocess.run(
            [QT6_RUNNER, '-input', str(directory)],
            env=dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software'),
            capture_output=True, text=True, timeout=20)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_qml_animation_lifecycle(self):
        self.run_qml(ROOT / 'tests/qml')

    def test_sidebar_menu_positioning(self):
        # Test the production state object without importing its entire module:
        # that module also registers hardware singletons requiring Quickshell.
        with tempfile.TemporaryDirectory(dir='/tmp/opencode') as temporary:
            directory = Path(temporary)
            source = (ROOT / 'globals/GlobalMenuState.qml').read_text()
            (directory / 'GlobalMenuState.qml').write_text(source.replace('pragma Singleton\n', '', 1))
            shutil.copyfile(ROOT / 'tests/fixtures/tst_sidebar_menu.qml', directory / 'tst_sidebar_menu.qml')
            self.run_qml(directory)


if __name__ == '__main__':
    unittest.main()
