"""Opt-in real Podman regression, run only on a host with the reviewed PG image.

NAS_RESTORE_INTEGRATION_IMAGE must name an already-loaded digest-pinned image.
All containers, files, SQL and HTTP traffic belong to these fixtures. In the
pre-fix implementation a shim redirects the production container name to our
sentinel, so the regression never executes SQL against a production cluster.
"""
import gzip
import importlib.util
import io
import json
import os
from pathlib import Path
import shlex
import shutil
import signal
import socket
import subprocess
import sys
import tarfile
import tempfile
import threading
import time
import unittest
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
IMAGE = os.environ.get('NAS_RESTORE_INTEGRATION_IMAGE')
SCHEMA = '\n'.join('CREATE TABLE public.' + name + ' (id integer);'
                   for name in ('users', 'workspaces', 'posts', 'media_attachments',
                                'fixture_a', 'fixture_b', 'fixture_c', 'fixture_d',
                                'fixture_e', 'fixture_f')) + '''
INSERT INTO users VALUES (1), (2);
INSERT INTO workspaces VALUES (1);
INSERT INTO posts VALUES (1), (2), (3);
INSERT INTO media_attachments VALUES (1);
'''


@unittest.skipUnless(IMAGE, 'set NAS_RESTORE_INTEGRATION_IMAGE for real Podman fixtures')
class PostgresIsolationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='nas-restore-isolation-')
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.label = 'nas-restore-isolation-' + uuid.uuid4().hex
        self.sentinel = self.label + '-sentinel'
        self.podman = shutil.which('podman')
        self.assertIsNotNone(self.podman)
        self.assertRegex(IMAGE, r'@sha256:[0-9a-f]{64}$')
        self.pod('image', 'exists', IMAGE)
        self.addCleanup(self.remove_fixtures)
        self.pod('run', '-d', '--pull=never', '--name', self.sentinel,
                 '--label', 'nas-restore-test=' + self.label,
                 '--network=none', '--user=postgres', '--read-only',
                 '--read-only-tmpfs=false', '--image-volume=ignore',
                 '--cap-drop=ALL', '--security-opt=no-new-privileges',
                 '--memory=256m', '--memory-swap=256m', '--cpus=0.5', '--pids-limit=64',
                 '--shm-size=16m', '--log-driver=none', '--http-proxy=false',
                 '--tmpfs', '/var/lib/postgresql/data:rw,size=128m,mode=1777',
                 '--tmpfs', '/var/run/postgresql:rw,size=4m,mode=1777',
                 '--tmpfs', '/tmp:rw,size=8m,mode=1777',
                 '-e', 'POSTGRES_HOST_AUTH_METHOD=trust', '-e', 'POSTGRES_USER=openpost',
                 '-e', 'POSTGRES_DB=openpost', '-e', 'PGDATA=/var/lib/postgresql/data/fixture', IMAGE,
                 'postgres', '-c', 'listen_addresses=', '-c', 'shared_buffers=16MB')
        for attempt in range(120):
            if self.pod('exec', self.sentinel, 'sh', '-ec',
                        'test "$(cat /proc/1/comm)" = postgres && '
                        'exec pg_isready -q -U openpost -d postgres', check=False).returncode == 0:
                break
            time.sleep(.25)
        else:
            self.fail('fixture PostgreSQL did not become ready')
        self.query("CREATE TABLE production_sentinel(value text); "
                   "INSERT INTO production_sentinel VALUES ('original');")
        self.pod('exec', self.sentinel, 'sh', '-c',
                 'printf original > /tmp/production-sentinel')
        self.host_sentinel = self.root / 'host-sentinel'
        self.host_sentinel.write_text('original')
        # Only this test shim knows the sentinel name. It makes the old unsafe
        # production target safe to exercise, without changing the restored SQL.
        binary = self.root / 'bin'
        binary.mkdir()
        shim = binary / 'podman'
        shim.write_text('#!' + sys.executable + '\nimport os,sys\n'
                        'args=[os.environ["TEST_PG_SENTINEL"] if x=="openpost-postgres" '
                        'else x for x in sys.argv[1:]]\n'
                        'if "psql" in args: os.dup2(os.open(os.devnull,os.O_WRONLY),2)\n'
                        'os.execv(os.environ["TEST_REAL_PODMAN"], ["podman", *args])\n')
        shim.chmod(0o700)
        environment = dict(PATH=str(binary) + os.pathsep + os.environ['PATH'],
                           NAS_RESTORE_POSTGRES_IMAGE=IMAGE,
                           NAS_RESTORE_CONTAINER_CIDFILE=str(self.root / 'restore.cid'),
                           TEST_PG_SENTINEL=self.sentinel, TEST_REAL_PODMAN=self.podman)
        self.environment = patch.dict(os.environ, environment)
        self.environment.start()
        self.addCleanup(self.environment.stop)
        spec = importlib.util.spec_from_file_location(
            'nas_restore_check', ROOT / 'modules/shared/nas-backup/restore_check.py')
        self.restore = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.restore)
        self.archive = self.root / 'database.gz'
        self.media = self.root / 'media.gz'
        with tarfile.open(self.media, 'w:gz') as archive:
            item = tarfile.TarInfo('media/fixture'); item.size = 5
            archive.addfile(item, io.BytesIO(b'image'))

    def pod(self, *args, check=True):
        result = subprocess.run([self.podman, *args], stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE if args[0] == 'run' else subprocess.DEVNULL,
                                timeout=60)
        if check and result.returncode:
            if args[0] == 'run':
                raise RuntimeError('fixture startup: ' + result.stderr.decode())
            result.check_returncode()
        return result

    def query(self, sql):
        return self.pod('exec', self.sentinel, 'psql', '-X', '-Atq',
                        '-v', 'ON_ERROR_STOP=1', '-U', 'openpost', '-d', 'postgres',
                        '-c', sql).stdout.strip()

    def remove_fixtures(self):
        self.pod('rm', '--force', '--ignore', self.sentinel)
        cidfile = self.root / 'restore.cid'
        if cidfile.exists():
            self.assertRegex(cidfile.read_text().strip(), r'^[0-9a-f]{64}$')
            self.pod('rm', '--force', '--ignore', '--cidfile', str(cidfile))

    def run_restore(self, sql):
        self.archive.write_bytes(gzip.compress(sql.encode()))
        return self.restore.openpost_check(self.archive, self.media)

    def assert_sentinels(self):
        self.assertEqual(self.query('SELECT value FROM production_sentinel'), b'original',
                         'untrusted restore changed the production-like cluster')
        self.assertEqual(self.pod('exec', self.sentinel, 'cat',
                                  '/tmp/production-sentinel').stdout, b'original',
                         'untrusted restore changed the production-like filesystem')
        self.assertEqual(self.host_sentinel.read_text(), 'original')

    def test_restore_counts_and_rejects_missing_media(self):
        self.assertEqual(self.run_restore(SCHEMA), dict(users=2, workspaces=1, posts=3,
                         public_tables=10, database_media=1, media_files=1))
        with tarfile.open(self.media, 'w:gz'):
            pass
        with self.assertRaisesRegex(ValueError, 'media records without media'):
            self.run_restore(SCHEMA)
        self.assert_sentinels()

    def test_untrusted_sql_and_psql_cannot_reach_sentinels(self):
        attacks = {
            'cluster': "\\connect postgres\nUPDATE production_sentinel SET value='compromised';\n",
            'server-file': "COPY (SELECT 'compromised') TO '/tmp/production-sentinel';\n",
            'server-program': "COPY (SELECT 1) TO PROGRAM 'printf compromised > /tmp/production-sentinel';\n",
            'client-shell': "\\! printf compromised > /tmp/production-sentinel\n",
            'host-file': "\\o " + str(self.host_sentinel) + "\nSELECT 'compromised';\n\\o\n",
        }
        for name, sql in attacks.items():
            with self.subTest(attack=name):
                self.query("UPDATE production_sentinel SET value='original'")
                self.pod('exec', self.sentinel, 'sh', '-c',
                         'printf original > /tmp/production-sentinel')
                try:
                    self.run_restore(SCHEMA + sql)
                except (ValueError, subprocess.CalledProcessError, BrokenPipeError):
                    pass
                self.assert_sentinels()

    def test_client_and_server_programs_cannot_reach_host_network(self):
        hits = []
        class Handler(BaseHTTPRequestHandler):
            def do_GET(self):
                hits.append(self.path)
                self.send_response(200); self.end_headers(); self.wfile.write(b'fixture')
            def log_message(self, *args):
                pass
        # Discover the host's routed source address without sending any packet.
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as probe:
            probe.connect(('192.0.2.1', 9))
            address = probe.getsockname()[0]
        server = ThreadingHTTPServer((address, 0), Handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        self.addCleanup(server.server_close)
        self.addCleanup(server.shutdown)
        endpoint = f'http://{address}:{server.server_port}/{self.label}'
        # Positive control: prove the host fixture endpoint works before attack.
        from urllib.request import build_opener, ProxyHandler
        with build_opener(ProxyHandler({})).open(endpoint, timeout=3) as response:
            self.assertEqual(response.read(), b'fixture')
        hits.clear()
        command = 'wget -q -T 2 -O /dev/null ' + shlex.quote(endpoint)
        # psql shell and SQL server program execution both remain inside the
        # isolated network namespace. No production address or service is used.
        sql = (SCHEMA + '\\! ' + command + '\n' +
               "CREATE TABLE network_probe(value text);\nCOPY network_probe FROM PROGRAM " +
               "'" + (command + ' || true').replace("'", "''") + "';\n")
        self.run_restore(sql)
        self.assertEqual(hits, [], 'restore reached a host-network sentinel')
        self.assert_sentinels()

    def test_signal_removes_running_restore_container(self):
        # Exercise the real CLI's signal handler, fetch path and Podman cleanup.
        # SSH serves only locally generated fixture bytes, never contacts NAS.
        self.archive.write_bytes(gzip.compress((SCHEMA + 'SELECT pg_sleep(30);\n').encode()))
        shim = self.root / 'bin' / 'ssh'
        shim.write_text('#!' + sys.executable + '''
import hashlib,json,os,sys
from pathlib import Path
dataset=sys.argv[-1].split()[-1]
path=Path(os.environ['FIXTURE_SQL'] if dataset=='openpost-db' else os.environ['FIXTURE_MEDIA'])
data=path.read_bytes()
label=dataset+'/snapshot-20261025T140000000000Z-'+'a'*32
sys.stdout.buffer.write(json.dumps(dict(label=label,bytes=len(data),checksum=hashlib.sha256(data).hexdigest())).encode()+b'\\n'+data)
''')
        shim.chmod(0o700)
        runtime = self.root / 'runtime'; runtime.mkdir()
        env = dict(os.environ, RUNTIME_DIRECTORY=str(runtime), FIXTURE_SQL=str(self.archive),
                   FIXTURE_MEDIA=str(self.media))
        proc = subprocess.Popen([sys.executable, str(ROOT / 'modules/shared/nas-backup/restore_check.py'),
                                 'openpost-db'], env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        def stop():
            if proc.poll() is None:
                proc.terminate()
            try:
                proc.communicate(timeout=15)
            except subprocess.TimeoutExpired:
                proc.kill(); proc.communicate()
        self.addCleanup(stop)
        cidfile = self.root / 'restore.cid'
        deadline = time.monotonic() + 60
        while time.monotonic() < deadline:
            self.assertIsNone(proc.poll(), 'restore exited before the interruption fixture')
            if cidfile.exists() and len(cidfile.read_text().strip()) == 64:
                cid = cidfile.read_text().strip()
                importing = self.pod('exec', cid, 'psql', '-X', '-Atqc',
                                     "SELECT count(*) FROM pg_stat_activity WHERE query='SELECT pg_sleep(30);'",
                                     '-U', 'openpost', '-d', 'openpost', check=False)
                if importing.returncode == 0 and importing.stdout.strip() == b'1':
                    break
            time.sleep(.25)
        else:
            self.fail('restore did not reach the interruptible fixture query')
        # Inspect only our known CID. These are the engine's applied settings,
        # and process status verifies non-root UID, empty capabilities and NNP.
        applied = json.loads(self.pod('inspect', cid).stdout)[0]
        host = applied['HostConfig']
        self.assertEqual(host['NetworkMode'], 'none')
        self.assertTrue(host['ReadonlyRootfs'])
        self.assertFalse(host['Binds'])
        self.assertFalse(host['PortBindings'])
        self.assertTrue(all(m['Type'] == 'tmpfs' for m in applied['Mounts']))
        self.assertEqual((host['Memory'], host['MemorySwap'], host['PidsLimit']),
                         (1536 * 1024**2, 1536 * 1024**2, 128))
        self.assertEqual(host['NanoCpus'], 1000000000)
        status = self.pod('exec', cid, 'cat', '/proc/self/status').stdout.decode()
        fields = dict(line.split(':', 1) for line in status.splitlines() if ':' in line)
        self.assertEqual(set(fields['Uid'].split()), {'70'})
        self.assertEqual(int(fields['CapEff'].strip(), 16), 0)
        self.assertEqual(fields['NoNewPrivs'].strip(), '1')
        proc.send_signal(signal.SIGTERM)
        proc.communicate(timeout=15)
        self.assertNotEqual(proc.returncode, 0)
        self.assertFalse(cidfile.exists())
        self.assertNotEqual(self.pod('container', 'exists', cid, check=False).returncode, 0)
        self.assertEqual(list(runtime.iterdir()), [])
        self.assert_sentinels()

    def test_untrusted_count_is_rejected_without_disclosure(self):
        sql = SCHEMA + '''
CREATE FUNCTION public.fake_count(text) RETURNS text LANGUAGE SQL AS
$$ SELECT repeat('fixture-private-value', 10000) $$;
CREATE AGGREGATE public.count(*) (SFUNC=public.fake_count, STYPE=text, INITCOND='');
ALTER ROLE openpost SET search_path=public,pg_catalog;
'''
        with self.assertRaises(ValueError) as error:
            self.run_restore(sql)
        self.assertTrue('fixture-private-value' not in str(error.exception),
                        'untrusted count bytes were disclosed in a host exception')
        self.assert_sentinels()


if __name__ == '__main__':
    unittest.main()
