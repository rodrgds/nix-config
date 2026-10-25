"""Receipt publication and freshness at the production CLI, using local fixtures."""
import datetime
import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / 'modules/shared/nas-backup/freshness.py'


class Freshness(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name) / 'receipts'
        self.root.mkdir(mode=0o700)
        self.target = self.root / 'directus.json'

    def receipt(self, hours=0):
        stamp = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(hours=hours)
        return {'verifiedAt': stamp.strftime('%Y-%m-%dT%H:%M:%SZ'),
                'checksum': 'a' * 64, 'bytes': 123, 'kind': 'tar-gzip',
                'label': 'directus/snapshot-' + stamp.strftime('%Y%m%dT%H%M%S000000Z-') + 'b' * 32}

    def cli(self, *arguments):
        return subprocess.run([sys.executable, '-I', str(SCRIPT),
                               '--state-dir', str(self.root), *arguments],
                              capture_output=True, timeout=10)

    def record(self, payload, exit_code=0):
        command = ('import sys; sys.stdout.write(' + repr(payload) +
                   '); sys.stdout.flush(); sys.exit(' + str(exit_code) + ')')
        return self.cli('record', 'directus', 'tar-gzip', '--', sys.executable, '-c', command)

    def save(self, receipt):
        self.target.write_text(json.dumps(receipt))
        self.target.chmod(0o600)

    def test_daily_deadline_rejects_stale_and_missing_expected_datasets(self):
        self.save(self.receipt(hours=37))
        stale = self.cli('check', 'directus:tar-gzip')
        self.assertNotEqual(stale.returncode, 0, stale.stdout)
        self.assertIn(b'directus: stale', stale.stderr)
        self.save(self.receipt(hours=35))
        self.assertEqual(self.cli('check', 'directus:tar-gzip').returncode, 0)
        missing = self.cli('check', 'directus:tar-gzip', 'umami-db:gzip')
        self.assertNotEqual(missing.returncode, 0)
        self.assertIn(b'umami-db: missing', missing.stderr)

    def test_sender_failure_after_valid_output_preserves_previous_receipt(self):
        self.save(self.receipt(hours=20))
        previous = self.target.read_bytes()
        failed = self.record(json.dumps(self.receipt()), exit_code=7)
        self.assertNotEqual(failed.returncode, 0)
        self.assertIn(b'sender failed', failed.stderr)
        self.assertEqual(self.target.read_bytes(), previous)
        self.assertEqual(list(self.root.iterdir()), [self.target])

    def test_success_publishes_private_receipt_and_invalid_output_preserves_it(self):
        good = self.receipt()
        result = self.record(json.dumps(good))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(self.target.read_bytes()), good)
        self.assertEqual(stat.S_IMODE(self.target.stat().st_mode), 0o600)
        self.assertEqual(stat.S_IMODE(self.root.stat().st_mode), 0o700)
        previous = self.target.read_bytes()
        for payload in ('{}', 'x' * 4097, '{bad json'):
            with self.subTest(payload=payload[:12]):
                failed = self.record(payload)
                self.assertNotEqual(failed.returncode, 0)
                self.assertEqual(self.target.read_bytes(), previous)
                self.assertEqual(list(self.root.iterdir()), [self.target])

    def test_untrusted_receipts_fail_closed_without_echoing_data(self):
        good = self.receipt()
        cases = [dict(good, verifiedAt=self.receipt(hours=-1)['verifiedAt']),
                 dict(good, verifiedAt='invalid'), dict(good, kind='gzip'),
                 dict(good, label='other/snapshot-data'), dict(good, checksum='bad'),
                 dict(good, bytes=True), dict(good, bytes=-1), []]
        for receipt in cases:
            with self.subTest(receipt=receipt):
                self.save(receipt)
                result = self.cli('check', 'directus:tar-gzip')
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn(b'snapshot-data', result.stderr)
        self.target.write_bytes(b'private-payload' * 400)
        self.assertNotEqual(self.cli('check', 'directus:tar-gzip').returncode, 0)
        self.target.unlink()
        os.symlink('absent', self.target)
        self.assertNotEqual(self.cli('check', 'directus:tar-gzip').returncode, 0)
        self.target.unlink()
        os.mkfifo(self.target)
        self.assertNotEqual(self.cli('check', 'directus:tar-gzip').returncode, 0)


if __name__ == '__main__':
    unittest.main()
