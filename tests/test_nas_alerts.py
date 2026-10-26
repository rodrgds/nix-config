"""Discord transport behavior on a local HTTP server and credential-safe CLI errors."""
import http.server
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import time
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / 'modules/shared/nas-backup/alert.py'
spec = importlib.util.spec_from_file_location('nas_alert', SCRIPT)
alert = importlib.util.module_from_spec(spec)
spec.loader.exec_module(alert)


class Transport(unittest.TestCase):
    def setUp(self):
        self.responses = [(200, {}, {'id': '123456789'})]
        self.received = []
        case = self

        class Handler(http.server.BaseHTTPRequestHandler):
            def do_POST(self):
                raw = self.rfile.read(int(self.headers['Content-Length']))
                case.received.append((time.monotonic(), self.path, json.loads(raw)))
                status, headers, body = case.responses.pop(0)
                self.send_response(status)
                for name, value in headers.items():
                    self.send_header(name, value)
                self.end_headers()
                self.wfile.write(json.dumps(body).encode())

            def log_message(self, *args):
                pass

        self.server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.addCleanup(self.cleanup)
        self.url = 'http://127.0.0.1:' + str(self.server.server_port) + '/fixture-credential'

    def cleanup(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()

    def test_confirmed_delivery_suppresses_mentions_and_requires_acknowledgement(self):
        alert.notify(self.url, 'Fixture failure @everyone')
        self.assertEqual(self.received[0][1], '/fixture-credential?wait=true')
        self.assertEqual(self.received[0][2], {
            'content': 'Fixture failure @everyone', 'allowed_mentions': {'parse': []}})
        self.responses = [(200, {}, {})]
        with self.assertRaisesRegex(alert.AlertError, 'did not acknowledge'):
            alert.notify(self.url, 'Unacknowledged fixture')

    def test_rate_limit_uses_server_delay_then_delivers(self):
        self.responses = [(429, {}, {'retry_after': 0.05}), (200, {}, {'id': '123'})]
        alert.notify(self.url, 'Fixture retry')
        self.assertEqual(len(self.received), 2)
        self.assertGreaterEqual(self.received[1][0] - self.received[0][0], 0.045)

    def test_redirects_and_excessive_rate_limit_delays_fail_without_forwarding(self):
        self.responses = [(302, {'Location': self.url + '/leak'}, {})]
        with self.assertRaisesRegex(alert.AlertError, 'HTTP 302'):
            alert.notify(self.url, 'Fixture redirect')
        self.assertEqual(len(self.received), 1)
        self.responses = [(429, {}, {'retry_after': 16})]
        with self.assertRaisesRegex(alert.AlertError, 'time budget'):
            alert.notify(self.url, 'Fixture long delay')
        self.assertEqual(len(self.received), 2)

    def test_rejected_credentials_are_not_retried_or_exposed(self):
        self.responses = [(404, {}, {'message': self.url})]
        with self.assertRaises(alert.AlertError) as caught:
            alert.notify(self.url, 'Fixture rejection')
        self.assertNotIn('fixture-credential', str(caught.exception))
        self.assertEqual(len(self.received), 1)


class CredentialCLI(unittest.TestCase):
    def test_unexpected_transport_errors_never_print_the_credential(self):
        with tempfile.TemporaryDirectory() as directory:
            credential = Path(directory) / 'discord-webhook'
            webhook = 'https://discord.com/api/webhooks/' + '1' * 18 + '/' + 'fixture-private-token-' * 3
            credential.write_text(webhook)
            wrapper = '''
import http.client, pathlib, runpy, sys
from types import SimpleNamespace
from unittest.mock import Mock, patch
script = sys.argv[1]
sys.argv = [script, '--systemctl', '/unused-systemctl', 'directus-backup.service']
opener = Mock()
opener.open.side_effect = http.client.InvalidURL(pathlib.Path(sys.argv[0]).name + ': fixture-private-token')
with patch('urllib.request.build_opener', return_value=opener), patch('subprocess.run', return_value=SimpleNamespace(stdout='exit-code')):
    runpy.run_path(script, run_name='__main__')
'''
            result = subprocess.run([sys.executable, '-I', '-c', wrapper, str(SCRIPT)],
                                    env={**os.environ, 'CREDENTIALS_DIRECTORY': directory},
                                    capture_output=True, text=True, timeout=5)
            self.assertNotEqual(result.returncode, 0)
            self.assertNotIn('fixture-private-token', result.stdout + result.stderr)
            self.assertNotIn('Traceback', result.stderr)

    def test_invalid_webhook_and_missing_credential_fail_without_exposing_values(self):
        with tempfile.TemporaryDirectory() as directory:
            credential = Path(directory) / 'discord-webhook'
            environment = {**os.environ, 'CREDENTIALS_DIRECTORY': directory}
            for value in ['https://untrusted.invalid/private-fixture-value', 'x' * 3000, None]:
                if value is None:
                    credential.unlink()
                else:
                    credential.write_text(value)
                    credential.chmod(0o600)
                result = subprocess.run([sys.executable, '-I', str(SCRIPT),
                                         '--systemctl', '/unused-systemctl', 'directus-backup.service'],
                                        env=environment, capture_output=True, text=True, timeout=5)
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn('private-fixture-value', result.stderr + result.stdout)
                self.assertNotIn('Traceback', result.stderr)
                self.assertIn('credential', result.stderr)


if __name__ == '__main__':
    unittest.main()
