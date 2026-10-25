"""Retrieve the latest NAS snapshot, checksum it, and restore in ephemeral state."""
import gzip
from contextlib import closing, contextmanager
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import resource
import signal
import socket
import sqlite3
import subprocess
import sys
import tarfile
import tempfile
import time
import uuid


# Restore budgets are deliberately narrower than receiver upload limits. Growth
# requires a reviewed capacity change, never a larger NAS-supplied manifest.
DATASET_LIMITS = {
    'openpost-db': (64 * 1024**2, 512 * 1024**2),
    'openpost-media': (768 * 1024**2, 2 * 1024**3),
    'directus': (64 * 1024**2, 512 * 1024**2),
}
MAX_TAR_HEADERS = 100000
MAX_TAR_METADATA_BYTES = 16 * 1024
MAX_TAR_TOTAL_METADATA_BYTES = 8 * 1024**2
CHUNK_BYTES = 1024 * 1024
SQLITE_FILE_BYTES = 256 * 1024**2


def sqlite_resource_limits():
    # Safe mode prohibits opening arbitrary persistent outputs, but SQL can
    # still expand its database and sort/temp files far beyond its input size.
    # Bound each actual file and the number simultaneously open, independently
    # of mutable SQLite PRAGMAs or NAS-claimed lengths (at most 4 GiB in total).
    resource.setrlimit(resource.RLIMIT_FSIZE, (SQLITE_FILE_BYTES, SQLITE_FILE_BYTES))
    resource.setrlimit(resource.RLIMIT_NOFILE, (16, 16))


class ExpandedReader:
    def __init__(self, source, limit):
        self.source = source
        self.remaining = limit

    def read(self, size=CHUNK_BYTES):
        # Never let a parser request an attacker-sized allocation. A one-byte
        # probe distinguishes exact-boundary EOF from real expanded overflow.
        data = self.source.read(min(size, CHUNK_BYTES, self.remaining + 1))
        if len(data) > self.remaining:
            raise ValueError('restore expanded byte limit exceeded')
        self.remaining -= len(data)
        return data


@contextmanager
def expanded_source(archive, dataset):
    with gzip.open(archive, 'rb') as compressed:
        source = ExpandedReader(compressed, DATASET_LIMITS[dataset][1])
        yield source
        # Tar EOF can precede gzip EOF, including concatenated gzip members.
        # Consume trailers too so they cannot bypass expansion or CRC checks.
        while source.read(CHUNK_BYTES):
            pass


class RestoreTarInfo(tarfile.TarInfo):
    def _proc_member(self, archive):
        # Check raw headers BEFORE tarfile allocates PAX/GNU metadata buffers or
        # recursively follows extension chains. Streaming alone does not do so.
        archive.restore_headers = getattr(archive, 'restore_headers', 0) + 1
        if archive.restore_headers > MAX_TAR_HEADERS:
            raise ValueError('restore tar header limit exceeded')
        metadata = self.type in (tarfile.XHDTYPE, tarfile.XGLTYPE, tarfile.SOLARIS_XHDTYPE,
                                 tarfile.GNUTYPE_LONGNAME, tarfile.GNUTYPE_LONGLINK)
        if metadata:
            archive.restore_metadata = getattr(archive, 'restore_metadata', 0) + self.size
            if (self.size > MAX_TAR_METADATA_BYTES or
                    archive.restore_metadata > MAX_TAR_TOTAL_METADATA_BYTES):
                raise ValueError('restore tar metadata limit exceeded')
        elif self.type not in (tarfile.REGTYPE, tarfile.AREGTYPE, tarfile.DIRTYPE):
            raise ValueError('unsafe restore archive type')
        depth = getattr(archive, 'restore_depth', 0)
        if depth >= 8:
            raise ValueError('restore tar extension depth limit exceeded')
        archive.restore_depth = depth + 1
        try:
            return super()._proc_member(archive)
        finally:
            archive.restore_depth = depth

    def _proc_gnusparse_00(self, *args):
        raise ValueError('unsafe sparse restore archive')

    _proc_gnusparse_01 = _proc_gnusparse_00
    _proc_gnusparse_10 = _proc_gnusparse_00


@contextmanager
def restore_tar(archive, dataset):
    with expanded_source(archive, dataset) as expanded:
        # Python 3.13 stream=True also disables TarInfo retention. r| alone
        # still caches every member, allowing tiny-file metadata amplification.
        with tarfile.open(fileobj=expanded, mode='r|', stream=True, tarinfo=RestoreTarInfo) as source:
            yield source


def safe_member(member):
    if (len(member.name.encode('utf-8', 'surrogateescape')) > 4096 or
            member.name.startswith('/') or '..' in member.name.split('/') or
            not (member.isfile() or member.isdir()) or member.size < 0):
        raise ValueError('unsafe restore archive')


def fetch(dataset, destination):
    maximum = DATASET_LIMITS[dataset][0]
    try:
        socket.getaddrinfo('rgo-nas', 22)
        host = 'rgo-nas'
    except socket.gaierror:
        host = '100.88.5.41'
    args = ['ssh', '-T', '-oBatchMode=yes', '-oIdentitiesOnly=yes',
            '-oStrictHostKeyChecking=yes', '-oUserKnownHostsFile=/etc/nas-backup/known_hosts',
            '-oGlobalKnownHostsFile=/dev/null', '-oHostKeyAlias=rgo-nas',
            '-oHostKeyAlgorithms=ssh-ed25519', '-oConnectTimeout=30',
            '-oServerAliveInterval=30', '-oServerAliveCountMax=3',
            '-i', os.environ.get('NAS_BACKUP_SSH_KEY', '/var/lib/nas-backup/id_ed25519'), 'kraktoos@' + host,
            'download ' + dataset]
    remote = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    try:
        line = remote.stdout.readline(4097)
        if not line.endswith(b'\n') or len(line) > 4096:
            raise ValueError('invalid NAS manifest')
        try:
            manifest = json.loads(line)
            # kind and verifiedAt are optional supplemental receipt fields.
            # The identity, actual length and SHA-256 are always mandatory.
            if (not isinstance(manifest, dict) or
                    not {'label', 'bytes', 'checksum'} <= manifest.keys() or
                    manifest.keys() - {'label', 'bytes', 'checksum', 'kind', 'verifiedAt'} or
                    not isinstance(manifest['label'], str) or
                    not re.fullmatch(re.escape(dataset) + r'/snapshot-\d{8}T\d{12}Z-[0-9a-f]{32}', manifest['label']) or
                    type(manifest['bytes']) is not int or not 0 < manifest['bytes'] <= maximum or
                    not isinstance(manifest['checksum'], str) or
                    not re.fullmatch('[0-9a-f]{64}', manifest['checksum']) or
                    manifest.get('kind', 'gzip' if dataset == 'openpost-db' else 'tar-gzip') !=
                    ('gzip' if dataset == 'openpost-db' else 'tar-gzip') or
                    ('verifiedAt' in manifest and (not isinstance(manifest['verifiedAt'], str) or
                     not re.fullmatch(r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z', manifest['verifiedAt'])))):
                raise ValueError
        except (ValueError, TypeError, KeyError):
            raise ValueError('invalid NAS manifest or restore byte limit') from None
        digest = hashlib.sha256()
        count = 0
        with open(destination, 'wb') as out:
            while True:
                chunk = remote.stdout.read(min(CHUNK_BYTES, manifest['bytes'] - count + 1))
                if not chunk:
                    break
                if count + len(chunk) > manifest['bytes']:
                    raise ValueError('NAS restore compressed byte limit exceeded')
                out.write(chunk)
                count += len(chunk)
                digest.update(chunk)
        if remote.wait() or count != manifest['bytes'] or digest.hexdigest() != manifest['checksum']:
            raise ValueError('NAS download checksum/size mismatch')
        return manifest
    except BaseException:
        Path(destination).unlink(missing_ok=True)
        raise
    finally:
        remote.stdout.close()
        if remote.poll() is None:
            remote.kill()
        remote.wait()


def sqlite_check(archive, directory):
    sql = []
    with restore_tar(archive, 'directus') as source:
        for member in source:
            safe_member(member)
            if re.fullmatch(r'database/\d{8}\.sql', member.name):
                if not member.isfile() or (sql and member.name <= sql[-1]):
                    raise ValueError('unordered or duplicate SQL chunks')
                sql.append(member.name)
    if not sql:
        raise ValueError('missing SQL chunks')
    # Validate the complete archive before creating any restored database. The
    # producer emits ascending SQL chunks, so a second streaming pass needs no
    # cached TarInfo objects or repeated gzip seeks.
    with restore_tar(archive, 'directus') as source:
        restored = Path(directory) / 'database.sqlite'
        # NAS checksums detect corruption, not a writer who can replace both
        # archive and manifest. Safe mode confines untrusted SQL to this database
        # and disables shell commands, extensions and external file operations.
        # Never log SQL text or query results from a credential-bearing backup.
        proc = subprocess.Popen(['sqlite3', '--safe', '-bail', str(restored)], stdin=subprocess.PIPE,
                                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                                preexec_fn=sqlite_resource_limits)
        try:
            for member in source:
                if not re.fullmatch(r'database/\d{8}\.sql', member.name):
                    continue
                with source.extractfile(member) as chunk:
                    while True:
                        data = chunk.read(1024 * 1024)
                        if not data:
                            break
                        proc.stdin.write(data)
            proc.stdin.close()
            if proc.wait():
                raise ValueError('SQLite restore failed')
        finally:
            if proc.poll() is None:
                proc.kill()
            proc.wait()
        with closing(sqlite3.connect(restored)) as db:
            if db.execute('PRAGMA integrity_check').fetchone()[0] != 'ok':
                raise ValueError('SQLite restored integrity check failed')
            if not db.execute("SELECT count(*) FROM sqlite_master WHERE type='table'").fetchone()[0]:
                raise ValueError('empty restored database')


def openpost_check(archive, media):
    # A NAS writer can replace SQL and its checksum together. Even psql itself
    # must run inside the disposable boundary: dumps can execute shell commands,
    # reconnect, load files and invoke server-side programs as the restore user.
    image = os.environ['NAS_RESTORE_POSTGRES_IMAGE']
    if not re.fullmatch(r'docker\.io/library/postgres:\d+-alpine@sha256:[0-9a-f]{64}', image):
        raise ValueError('restore requires a digest-pinned PostgreSQL Alpine image')
    container = 'nas-openpost-restore-' + uuid.uuid4().hex
    cidfile = os.environ.get('NAS_RESTORE_CONTAINER_CIDFILE')
    if cidfile and Path(cidfile).exists():
        raise ValueError('previous restore container receipt requires cleanup')

    def podman(*args, **kwargs):
        return subprocess.run(['podman', *args], check=True,
                              stderr=subprocess.DEVNULL, **kwargs)

    client = ['psql', '-X', '-h', '/var/run/postgresql', '-U', 'openpost', '-d', 'openpost',
              '-v', 'ON_ERROR_STOP=1']
    try:
        # No image-declared anonymous volumes, inherited proxies, bind mounts,
        # credentials or network. UID/GID 70 is postgres in the reviewed Alpine
        # image. All writable application storage is size-limited tmpfs and is
        # also charged to the container's memory cgroup (swap disabled).
        podman('create', '--name', container, '--pull=never',
               '--cgroup-parent=machine.slice',
               '--label=nas-backup-restore=openpost', '--network=none', '--no-hosts',
               '--pid=private', '--ipc=private', '--uts=private',
               '--user=70:70', '--read-only', '--read-only-tmpfs=false',
               '--image-volume=ignore', '--cap-drop=ALL', '--security-opt=no-new-privileges',
               '--http-proxy=false', '--log-driver=none',
               '--memory=1536m', '--memory-swap=1536m', '--cpus=1', '--pids-limit=128',
               '--shm-size=16m',
               '--tmpfs=/dev/shm:rw,noexec,nosuid,nodev,size=16m,mode=1777',
               '--tmpfs=/var/lib/postgresql/data:rw,noexec,nosuid,nodev,size=1g,mode=1777',
               '--tmpfs=/var/run/postgresql:rw,noexec,nosuid,nodev,size=8m,mode=1777',
               '--tmpfs=/tmp:rw,noexec,nosuid,nodev,size=64m,mode=1777',
               '--env=POSTGRES_HOST_AUTH_METHOD=trust', '--env=POSTGRES_USER=openpost',
               '--env=POSTGRES_DB=openpost',
               '--env=PGDATA=/var/lib/postgresql/data/restore',
               *(['--cidfile', cidfile] if cidfile else []), image,
               'postgres', '-c', 'listen_addresses=', '-c', 'shared_buffers=32MB',
               '-c', 'max_connections=10', stdout=subprocess.DEVNULL)
        podman('start', container, stdout=subprocess.DEVNULL)
        for attempt in range(120):
            # The image entrypoint briefly starts a bootstrap server before
            # exec'ing the final postgres process. Do not restore into that
            # server while initialization is still in progress.
            ready = subprocess.run(['podman', 'exec', container, 'sh', '-ec',
                                    'test "$(cat /proc/1/comm)" = postgres && '
                                    'exec pg_isready -q -h /var/run/postgresql -U openpost -d openpost'],
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            if ready.returncode == 0:
                break
            time.sleep(.5)
        else:
            raise ValueError('disposable PostgreSQL did not become ready')
        proc = subprocess.Popen(['podman', 'exec', '-i', container, *client], stdin=subprocess.PIPE,
                                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        try:
            with expanded_source(archive, 'openpost-db') as source:
                while True:
                    chunk = source.read(1024 * 1024)
                    if not chunk:
                        break
                    proc.stdin.write(chunk)
            proc.stdin.close()
            if proc.wait():
                raise ValueError('PostgreSQL restore failed')
        finally:
            if proc.poll() is None:
                proc.kill()
            proc.wait()
        def count(query):
            # SQL can replace aggregates/search paths too. Bound the result
            # before bringing it into host memory, and never include it in an
            # exception (int() would quote untrusted database contents).
            counter = subprocess.Popen(['podman', 'exec', container, *client, '-Atqc', query],
                                       stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
            try:
                result = counter.stdout.read(64)
                if len(result) == 64 or not re.fullmatch(rb'[0-9]+\n', result):
                    raise ValueError('invalid PostgreSQL restore count')
                if counter.wait():
                    raise ValueError('PostgreSQL restore count failed')
                return int(result)
            finally:
                counter.stdout.close()
                if counter.poll() is None:
                    counter.kill()
                counter.wait()
        tables = count("SELECT count(*) FROM information_schema.tables WHERE table_schema='public'")
        if tables < 10:
            raise ValueError('too few restored public tables')
        counts = {table: count('SELECT count(*) FROM ' + table)
                  for table in ('users', 'workspaces', 'posts')}
        records = count('SELECT count(*) FROM media_attachments')
        with restore_tar(media, 'openpost-media') as source:
            files = 0
            for member in source:
                safe_member(member)
                files += member.isfile()
        if records and not files:
            raise ValueError('media records without media snapshot files')
        return dict(counts, public_tables=tables, database_media=records, media_files=files)
    finally:
        podman('rm', '--force', '--ignore', container, stdout=subprocess.DEVNULL)
        if cidfile:
            Path(cidfile).unlink(missing_ok=True)


def main():
    def interrupted(signum, frame):
        # A service stop must unwind the restore and remove its whole container.
        signal.signal(signal.SIGTERM, signal.SIG_IGN)
        signal.signal(signal.SIGINT, signal.SIG_IGN)
        raise InterruptedError('restore interrupted')

    signal.signal(signal.SIGTERM, interrupted)
    signal.signal(signal.SIGINT, interrupted)
    os.umask(0o077)
    dataset = sys.argv[1]
    # systemd provides private disk-backed CacheDirectory. RUNTIME_DIRECTORY is
    # retained only for standalone fixture callers predating that wiring.
    cache = os.environ.get('CACHE_DIRECTORY', os.environ.get('RUNTIME_DIRECTORY'))
    if 'CACHE_DIRECTORY' in os.environ:
        cache = Path(cache) / 'staging'
        cache.mkdir(mode=0o700)
    with tempfile.TemporaryDirectory(prefix='nas-restore-', dir=cache) as directory:
        archive = Path(directory) / 'data.gz'
        receipt = fetch(dataset, archive)
        if dataset == 'directus':
            sqlite_check(archive, directory)
        elif dataset == 'openpost-db':
            media = Path(directory) / 'media.gz'
            fetch('openpost-media', media)
            checks = openpost_check(archive, media)
            evidence = dict(checks, status='passed',
                            checked_at=datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
                            backup=receipt['label'], backup_bytes=receipt['bytes'])
            destination = Path('/var/backup/openpost/restore-drill-latest.json')
            destination.parent.mkdir(parents=True, exist_ok=True)
            temporary = destination.with_suffix('.json.tmp')
            temporary.write_text(json.dumps(evidence) + '\n')
            os.replace(temporary, destination)
        else:
            raise ValueError('unsupported restore check')
        print(json.dumps({'status': 'passed', 'snapshot': receipt['label']}), flush=True)


if __name__ == '__main__':
    try:
        main()
    except Exception:
        # Parser/engine exceptions can contain NAS-supplied names or SQL bytes.
        sys.exit('NAS restore failed: invalid input, resource limit, or unavailable dependency')
