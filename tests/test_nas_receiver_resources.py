"""Resource regressions at the standalone receiver's upload/CLI boundary.

Linux tests also run in a disposable, unprivileged container. No NAS data,
credentials, database service or production receiver installation is used.
"""
import gzip
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import resource
import struct
import subprocess
import sys
import tarfile
import tempfile
import time
import unittest
from unittest.mock import patch


RECEIVER = Path(__file__).resolve().parents[1] / 'modules/shared/nas-backup/receiver.py'


def wire(payload):
    frames = b''.join(struct.pack('!I', len(payload[n:n + 1024 * 1024])) +
                      payload[n:n + 1024 * 1024]
                      for n in range(0, len(payload), 1024 * 1024))
    commit = {'sha256': hashlib.sha256(payload).hexdigest(), 'bytes': len(payload)}
    return frames + b'\0' * 4 + json.dumps(commit).encode() + b'\n'


def archive(entries):
    data = io.BytesIO()
    with tarfile.open(fileobj=data, mode='w', format=tarfile.PAX_FORMAT) as output:
        for name, metadata in entries:
            member = tarfile.TarInfo(name)
            member.size = 4
            member.pax_headers = metadata
            output.addfile(member, io.BytesIO(b'data'))
    return gzip.compress(data.getvalue())


class ReceiverResources(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name).resolve() / 'backups'
        self.root.mkdir()

    def tearDown(self):
        self.temporary.cleanup()

    def upload(self, payload, dataset='openpost-media', before_exec=None):
        kind = 'tar-gzip' if dataset in ('openpost-media', 'directus', 'vaultwarden') else 'gzip'
        return subprocess.run(
            [sys.executable, '-I', str(RECEIVER), '--root', str(self.root)],
            input=wire(payload), capture_output=True, timeout=45,
            env=dict(os.environ, SSH_ORIGINAL_COMMAND='upload ' + dataset + ' ' + kind),
            preexec_fn=before_exec)

    def test_metadata_rejection_removes_partial_and_preserves_snapshot(self):
        previous = archive([('media/previous', {})])
        good = self.upload(previous)
        self.assertEqual(good.returncode, 0, good.stderr)
        label = json.loads(good.stdout)['label']
        before = sorted((self.root / 'openpost-media').iterdir())
        # These are valid, tiny compressed archives, accepted by the old parser.
        # Both GNU and PAX extension allocation must be checked before reading.
        longname = tarfile.TarInfo('media/' + 'a' * (64 * 1024))
        gnu = longname.tobuf(format=tarfile.GNU_FORMAT) + b'\0' * 1024
        cases = [
            ('PAX', archive([('media/asset', {'comment': 'a' * (64 * 1024)})])),
            ('GNU', gzip.compress(gnu)),
            ('path', archive([('media/' + 'b' * 4096, {})])),
        ]
        # Nested global headers recurse inside TarInfo before yielding a member.
        global_header = tarfile.TarInfo('pax')
        global_header.type = tarfile.XGLTYPE
        nested = global_header.tobuf() * 9 + tarfile.TarInfo('media/asset').tobuf()
        cases.append(('depth', gzip.compress(nested + b'\0' * 1024)))
        for name, payload in cases:
            with self.subTest(name=name):
                failed = self.upload(payload)
                self.assertNotEqual(failed.returncode, 0, failed.stdout)
                self.assertIn(b'limit', failed.stderr)
                self.assertEqual(sorted((self.root / 'openpost-media').iterdir()), before)
                self.assertEqual((self.root / label / 'data.gz').read_bytes(), previous)

    def test_cumulative_metadata_is_bounded(self):
        payload = archive([('media/asset', {'comment': 'x' * 60000})] * 280)
        failed = self.upload(payload)
        self.assertNotEqual(failed.returncode, 0, failed.stdout)
        self.assertIn(b'metadata limit', failed.stderr)
        self.assertEqual(list((self.root / 'openpost-media').glob('.partial-*')), [])
        self.assertEqual(list((self.root / 'openpost-media').glob('snapshot-*')), [])

    def test_header_budget_counts_extensions_before_logical_members(self):
        spec = importlib.util.spec_from_file_location('receiver', RECEIVER)
        receiver = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(receiver)
        payload = archive([('media/one', {'comment': 'one'}),
                           ('media/two', {'comment': 'two'})])
        # Two logical files have four physical headers. A small fixture budget
        # exercises that distinction without constructing half a GiB of headers.
        with patch.object(receiver, 'MAX_TAR_HEADERS', 3, create=True):
            with self.assertRaisesRegex(ValueError, 'header limit'):
                receiver.receive(str(self.root), 'upload openpost-media tar-gzip',
                                 io.BytesIO(wire(payload)))
        self.assertEqual(list((self.root / 'openpost-media').glob('.partial-*')), [])

    def test_cli_limit_failure_does_not_start_transfer(self):
        launcher = '''import runpy, sys
from unittest.mock import patch
receiver = runpy.run_path(sys.argv[1])
sys.argv = [sys.argv[1], '--root', sys.argv[2]]
with patch('resource.setrlimit', side_effect=OSError('fixture limit failure')):
    sys.exit(receiver['main']())
'''
        result = subprocess.run(
            [sys.executable, '-I', '-c', launcher, str(RECEIVER), str(self.root)],
            input=wire(gzip.compress(b'normal')), capture_output=True, timeout=10,
            env=dict(os.environ, SSH_ORIGINAL_COMMAND='upload montra-db gzip'))
        if sys.platform == 'linux':
            self.assertNotEqual(result.returncode, 0)
            self.assertIn(b'fixture limit failure', result.stderr)
            self.assertEqual(list(self.root.iterdir()), [])
        else:
            # Darwin fixture roots must not attempt Linux-only address limits.
            self.assertEqual(result.returncode, 0, result.stderr)

    def test_normal_archives_and_database_cli_remain_compatible(self):
        payload = archive([('media/' + 'nested/' * 30 + 'ação.txt', {'comment': 'ordinary'})])
        for dataset in ('openpost-media', 'directus', 'vaultwarden', 'montra-db',
                        'openpost-db', 'umami-db', 'shlink-db', 'unprompted-db'):
            with self.subTest(dataset=dataset):
                compressed = payload if dataset in ('openpost-media', 'directus', 'vaultwarden') else gzip.compress(b'SELECT 1;\n')
                result = self.upload(compressed, dataset)
                self.assertEqual(result.returncode, 0, result.stderr)
                receipt = json.loads(result.stdout)
                self.assertEqual(receipt['checksum'], hashlib.sha256(compressed).hexdigest())
                self.assertEqual((self.root / receipt['label'] / 'data.gz').read_bytes(), compressed)

    @unittest.skipUnless(sys.platform == 'linux', 'Linux address-space semantics')
    def test_many_members_succeed_under_inherited_memory_budget(self):
        # No retained member list is needed to validate a stream. The inherited
        # hard budget also proves the CLI never raises an existing lower limit.
        data = io.BytesIO()
        with gzip.GzipFile(fileobj=data, mode='wb') as zipped:
            for index in range(120000):
                # Distinct names keep this a member-retention regression,
                # without the old gzip adapter's high-ratio buffering cost.
                name = 'media/' + hashlib.sha256(str(index).encode()).hexdigest()
                zipped.write(tarfile.TarInfo(name).tobuf())
            zipped.write(b'\0' * 1024)

        def smaller_budget():
            resource.setrlimit(resource.RLIMIT_AS, (64 * 1024 ** 2,) * 2)

        result = self.upload(data.getvalue(), before_exec=smaller_budget)
        self.assertEqual(result.returncode, 0, result.stderr)

    @unittest.skipUnless(sys.platform == 'linux', 'Linux /proc limits')
    def test_cli_has_hard_os_limits_before_reading_upload(self):
        process = subprocess.Popen(
            [sys.executable, '-I', str(RECEIVER), '--root', str(self.root)],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            env=dict(os.environ, SSH_ORIGINAL_COMMAND='upload montra-db gzip'))
        try:
            deadline = time.monotonic() + 5
            while not list(self.root.glob('montra-db/.partial-*')):
                self.assertIsNone(process.poll(), 'receiver exited before reading input')
                self.assertLess(time.monotonic(), deadline)
                time.sleep(0.01)
            limits = Path('/proc/{}/limits'.format(process.pid)).read_text()
            for label, maximum in [('Max address space', 512 * 1024 ** 2),
                                   ('Max open files', 64), ('Max core file size', 0)]:
                with self.subTest(limit=label):
                    fields = next(line[len(label):].split() for line in limits.splitlines()
                                  if line.startswith(label))
                    self.assertNotEqual(fields[0], 'unlimited', limits)
                    self.assertNotEqual(fields[1], 'unlimited', limits)
                    self.assertLessEqual(int(fields[0]), maximum)
                    self.assertLessEqual(int(fields[1]), maximum)
            process.terminate()
            process.communicate(timeout=5)
            self.assertNotEqual(process.returncode, 0)
            self.assertEqual(list(self.root.glob('montra-db/.partial-*')), [])
        finally:
            if process.poll() is None:
                process.kill()
            process.communicate()


if __name__ == '__main__':
    unittest.main()
