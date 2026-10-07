#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

require_command python3

python3 - <<'PY'
import json
import os
from pathlib import Path
import runpy
import subprocess
import sys
import tempfile
import unittest

root = Path(os.environ['ROOT'])


class ShareTextTests(unittest.TestCase):
  def setUp(self):
    self.scratch = tempfile.TemporaryDirectory()
    self.addCleanup(self.scratch.cleanup)
    self.directory = Path(self.scratch.name)
    self.calls = self.directory / 'calls.json'
    self.environment = dict(os.environ, OMARCHY_PATH=str(self.directory),
                            HOME=str(self.directory), SHARE_TEST_CALLS=str(self.calls),
                            SHARE_TEST_NOTIFICATION=str(self.directory / 'notification'))
    self.environment['PATH'] = str(self.directory) + os.pathsep + os.environ['PATH']
    self.stub('systemd-run', f'''#!{sys.executable}
import json, os, sys
from pathlib import Path
Path(os.environ['SHARE_TEST_CALLS']).write_text(json.dumps(sys.argv[1:]))
sys.exit(int(os.environ.get('SHARE_TEST_LAUNCH_STATUS', '0')))
''')
    composer = self.directory / 'default/localsend/share-text.py'
    composer.parent.mkdir(parents=True)
    composer.write_text("import os, sys\nprint(os.environ.get('SHARE_TEST_MESSAGE', ''), end='')\nsys.exit(int(os.environ.get('SHARE_TEST_COMPOSER_STATUS', '0')))\n")
    # A PATH-selected Python must never replace Arch's GI-enabled interpreter.
    self.stub('python3', '#!/bin/bash\nexit 99\n')
    self.stub('omarchy-notification-send', '#!/bin/bash\nprintf "%s\\n" "$@" > "$SHARE_TEST_NOTIFICATION"\n')

  def stub(self, name, text):
    path = self.directory / name
    path.write_text(text)
    path.chmod(0o755)

  def share(self, *arguments):
    return subprocess.run(['bash', str(root / 'bin/omarchy-menu-share'), *arguments],
                          env=self.environment, capture_output=True, text=True)

  def test_composed_message_is_native_text_and_literal(self):
    message = 'café 🌎\n$(touch unwanted); "quoted"'
    self.environment['SHARE_TEST_MESSAGE'] = message
    result = self.share('text')
    self.assertEqual(result.returncode, 0, result.stderr)
    self.assertEqual(json.loads(self.calls.read_text())[-3:], ['localsend', '--text', ' ' + message])
    self.assertFalse((self.directory / 'unwanted').exists())

  def test_cancel_and_blank_do_not_launch(self):
    for message, status in [('', '1'), ('', '0'), (' \t\n', '0')]:
      self.environment.update(SHARE_TEST_MESSAGE=message, SHARE_TEST_COMPOSER_STATUS=status)
      self.assertEqual(self.share('text').returncode, 0)
      self.assertFalse(self.calls.exists())

  def test_composer_error_does_not_launch(self):
    self.environment.update(SHARE_TEST_MESSAGE='partial', SHARE_TEST_COMPOSER_STATUS='2')
    self.assertNotEqual(self.share('text').returncode, 0)
    self.assertFalse(self.calls.exists())
    self.assertIn('The text composer did not open', (self.directory / 'notification').read_text())

  def test_flag_like_direct_text_is_not_an_option(self):
    self.assertEqual(self.share('text', '--share').returncode, 0)
    self.assertEqual(json.loads(self.calls.read_text())[-3:], ['localsend', '--text', ' --share'])

  def test_launch_failure_propagates(self):
    self.environment['SHARE_TEST_LAUNCH_STATUS'] = '1'
    self.assertNotEqual(self.share('text', 'hello').returncode, 0)
    self.assertIn('LocalSend did not open', (self.directory / 'notification').read_text())

  def test_existing_file_and_folder_paths_remain_files(self):
    for mode in ('file', 'folder'):
      self.assertEqual(self.share(mode, '/a path').returncode, 0)
      self.assertEqual(json.loads(self.calls.read_text())[-4:], ['localsend', '--headless', 'send', '/a path'])

  def test_real_composer_imports_matching_toolkits(self):
    try:
      import gi
      gi.require_version('Gtk', '3.0')
      gi.require_version('Gdk', '3.0')
    except (ImportError, ValueError):
      self.skipTest('GTK/GDK 3 introspection unavailable')
    probe = '''
import runpy, sys
module = runpy.run_path(sys.argv[1])
class ImportsVerified(Exception): pass
def trace(frame, event, arg):
  if frame.f_code.co_name == 'compose_text' and event == 'line' and 'Gtk' in frame.f_locals:
    assert frame.f_locals['Gtk']._version == '3.0'
    assert frame.f_locals['Gdk']._version == '3.0'
    raise ImportsVerified()
  return trace
sys.settrace(trace)
try:
  module['compose_text']()
except ImportsVerified:
  sys.settrace(None)
  print('GTK/GDK 3 imports verified')
'''
    result = subprocess.run([sys.executable, '-c', probe, str(root / 'default/localsend/share-text.py')],
                            text=True, capture_output=True)
    self.assertEqual(result.returncode, 0, result.stderr)
    self.assertIn('GTK/GDK 3 imports verified', result.stdout)


unittest.main()
PY

pass "text sharing handles cancellation, errors, literal messages, and toolkit versions"

run_node_test <<'JS'
const fs = require('fs')
const model = requireFromRoot('shell/plugins/menu/MenuModel.js')
const entries = model.parseMenuJsonc(fs.readFileSync(path.join(root, 'default/omarchy/omarchy-menu.jsonc'), 'utf8'))
const text = entries.find(entry => entry.id === 'trigger.share.text')
assert(text && text.parent === 'trigger.share' && text.action === 'omarchy-menu-share text', 'Share menu routes Text to text sharing')
JS
