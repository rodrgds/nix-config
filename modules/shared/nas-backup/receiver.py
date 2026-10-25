#!/usr/bin/python3
"""Forced SSH receiver. SSH_ORIGINAL_COMMAND is data, never a shell command.

Frames: uint32 network-order length + bytes; zero length then a bounded JSON
commit line. EOF alone is NOT producer success. Only the sender, after waiting
for the entire pipefail producer, may emit that commit.
"""
import argparse
import datetime
import fcntl
import gzip
import hashlib
import json
import os
import re
import resource
import signal
import stat
import struct
import sys
import tarfile
import uuid

ROOT = '/volume1/homes/kraktoos/Backups/rgo-vps'
DATASETS = {'montra-db', 'openpost-db', 'openpost-media', 'umami-db',
            'shlink-db', 'unprompted-db', 'directus', 'vaultwarden'}
ARCHIVE_DATASETS = {'openpost-media', 'directus', 'vaultwarden'}
MAX_FRAME = 1024 * 1024
# Bound each transfer even when its dedicated SSH identity is compromised.
# Keep growth headroom over the October 2026 baseline (about 4 GiB compressed),
# while bounding upload storage and gzip verification work.
MAX_UPLOAD_BYTES = 16 * 1024 ** 3
MAX_EXPANDED_BYTES = 128 * 1024 ** 3
MAX_ADDRESS_SPACE = 512 * 1024 ** 2
MAX_OPEN_FILES = 64
MAX_TAR_HEADERS = 1000000
MAX_TAR_METADATA_BYTES = 64 * 1024
MAX_TAR_TOTAL_METADATA_BYTES = 16 * 1024 ** 2
KEEP = 7
DIRECTORY = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW
FILE = os.O_NOFOLLOW | os.O_CLOEXEC


def resource_limits(root):
    # DSM's Linux kernel enforces RLIMIT_AS without a cgroup or privileges.
    # Darwin has different address-space semantics; explicit alternate roots
    # remain usable for local fixtures, but the production root fails closed.
    if sys.platform != 'linux':
        if root == ROOT:
            raise RuntimeError('production receiver requires Linux resource limits')
        return
    for kind, maximum in ((resource.RLIMIT_AS, MAX_ADDRESS_SPACE),
                          (resource.RLIMIT_NOFILE, MAX_OPEN_FILES),
                          (resource.RLIMIT_CORE, 0)):
        current = resource.getrlimit(kind)
        limit = min([maximum] + [value for value in current
                                 if value != resource.RLIM_INFINITY])
        # Never raise an inherited limit. Lower both so parsing cannot relax it.
        resource.setrlimit(kind, (limit, limit))


class ReceiverTarInfo(tarfile.TarInfo):
    def _proc_member(self, archive):
        # Python 3.8 streaming tar still allocates extension payloads and
        # recursively follows their chains before yielding a logical member.
        archive.receiver_headers = getattr(archive, 'receiver_headers', 0) + 1
        if archive.receiver_headers > MAX_TAR_HEADERS:
            raise ValueError('tar header limit exceeded')
        if self.size < 0 or self.size > MAX_EXPANDED_BYTES:
            raise ValueError('tar member size limit exceeded')
        if self.type in (tarfile.XHDTYPE, tarfile.XGLTYPE, tarfile.SOLARIS_XHDTYPE,
                         tarfile.GNUTYPE_LONGNAME, tarfile.GNUTYPE_LONGLINK):
            archive.receiver_metadata = getattr(archive, 'receiver_metadata', 0) + self.size
            if (self.size > MAX_TAR_METADATA_BYTES or
                    archive.receiver_metadata > MAX_TAR_TOTAL_METADATA_BYTES):
                raise ValueError('tar metadata limit exceeded')
        elif self.type not in (tarfile.REGTYPE, tarfile.AREGTYPE, tarfile.DIRTYPE):
            raise ValueError('archive links and special files are not restorable safely')
        depth = getattr(archive, 'receiver_depth', 0)
        if depth >= 8:
            raise ValueError('tar extension depth limit exceeded')
        archive.receiver_depth = depth + 1
        try:
            return super()._proc_member(archive)
        finally:
            archive.receiver_depth = depth

    def _proc_gnusparse_00(self, *args):
        raise ValueError('sparse archives are not restorable safely')

    _proc_gnusparse_01 = _proc_gnusparse_00
    _proc_gnusparse_10 = _proc_gnusparse_00


def open_root(path):
    if not path.startswith('/'):
        raise ValueError('root must be absolute')
    fd = os.open('/', DIRECTORY)
    try:
        for part in path.split('/')[1:]:
            if not part or part in ('.', '..'):
                raise ValueError('invalid root')
            next_fd = os.open(part, DIRECTORY, dir_fd=fd)
            os.close(fd)
            fd = next_fd
        return fd
    except BaseException:
        os.close(fd)
        raise


def exact(stream, size):
    chunks = bytearray()
    while len(chunks) < size:
        chunk = stream.read(size - len(chunks))
        if not chunk:
            raise ValueError('EOF without sender-success commit')
        chunks.extend(chunk)
    return bytes(chunks)


def remove_snapshot(parent, name):
    # Never follow directory or file symlinks, even during cleanup/retention.
    fd = os.open(name, DIRECTORY, dir_fd=parent)
    try:
        for filename in os.listdir(fd):
            if filename not in {'data.gz', 'manifest.json'}:
                raise ValueError('unexpected snapshot content')
            mode = os.stat(filename, dir_fd=fd, follow_symlinks=False).st_mode
            if not stat.S_ISREG(mode):
                raise ValueError('non-regular snapshot content')
        for filename in os.listdir(fd):
            os.unlink(filename, dir_fd=fd)
    finally:
        os.close(fd)
    os.rmdir(name, dir_fd=parent)


def verify(fd, kind):
    os.lseek(fd, 0, os.SEEK_SET)
    # Consume the whole gzip, including CRC/trailer and concatenated members.
    with os.fdopen(os.dup(fd), 'rb') as raw, gzip.GzipFile(fileobj=raw) as zipped:
        size = 0
        tail = b''
        while True:
            chunk = zipped.read(min(MAX_FRAME, MAX_EXPANDED_BYTES - size + 1))
            if not chunk:
                break
            size += len(chunk)
            if size > MAX_EXPANDED_BYTES:
                raise ValueError('expanded byte limit exceeded')
            tail = (tail + chunk)[-1024:]
    if not size:
        raise ValueError('empty uncompressed backup')
    if kind != 'tar-gzip':
        return
    if size % 512 or tail != b'\0' * 1024:
        raise ValueError('missing tar end blocks')
    os.lseek(fd, 0, os.SEEK_SET)
    with os.fdopen(os.dup(fd), 'rb') as raw, gzip.GzipFile(fileobj=raw) as zipped, \
            tarfile.open(fileobj=zipped, mode='r|', tarinfo=ReceiverTarInfo) as archive:
        while True:
            member = archive.next()
            if member is None:
                break
            # r|gz alone retains every TarInfo on Python 3.8. We only need the
            # current member, and cannot use Python 3.13's stream=True on DSM.
            archive.members.clear()
            path = member.name
            if len(path.encode('utf-8', 'surrogateescape')) > 4096:
                raise ValueError('archive path limit exceeded')
            if path.startswith('/') or '..' in path.split('/') or member.size < 0:
                raise ValueError('unsafe archive member')
            if not (member.isfile() or member.isdir()):
                raise ValueError('archive links and special files are not restorable safely')
            if member.isfile():
                file = archive.extractfile(member)
                remaining = member.size
                while remaining:
                    chunk = file.read(min(MAX_FRAME, remaining))
                    if not chunk:
                        raise ValueError('truncated tar member')
                    remaining -= len(chunk)


def receive(root, command, stream):
    match = re.fullmatch(r'upload ([a-z-]+) (gzip|tar-gzip)', command)
    if not match or match[1] not in DATASETS:
        raise ValueError('command not allowed')
    dataset, kind = match.groups()
    expected_kind = 'tar-gzip' if dataset in ARCHIVE_DATASETS else 'gzip'
    if kind != expected_kind:
        raise ValueError('wrong format for dataset')
    rootfd = open_root(root)
    parent = stagefd = lockfd = datafd = None
    stage = None
    try:
        try:
            os.mkdir(dataset, 0o700, dir_fd=rootfd)
        except FileExistsError:
            pass
        parent = os.open(dataset, DIRECTORY, dir_fd=rootfd)
        lockfd = os.open('.lock', os.O_CREAT | os.O_RDWR | FILE, 0o600, dir_fd=parent)
        if not stat.S_ISREG(os.fstat(lockfd).st_mode):
            raise ValueError('invalid lock')
        fcntl.flock(lockfd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        # A killed receiver may leave a partial. Under the lock it cannot be live.
        for name in os.listdir(parent):
            if re.fullmatch(r'\.partial-[0-9a-f]{32}', name):
                remove_snapshot(parent, name)
        stage = '.partial-' + uuid.uuid4().hex
        os.mkdir(stage, 0o700, dir_fd=parent)
        stagefd = os.open(stage, DIRECTORY, dir_fd=parent)
        datafd = os.open('data.gz', os.O_CREAT | os.O_EXCL | os.O_RDWR | FILE, 0o600, dir_fd=stagefd)
        digest = hashlib.sha256()
        count = 0
        with os.fdopen(os.dup(datafd), 'wb') as out:
            while True:
                size = struct.unpack('!I', exact(stream, 4))[0]
                if not size:
                    break
                if size > MAX_FRAME:
                    raise ValueError('frame too large')
                if count + size > MAX_UPLOAD_BYTES:
                    raise ValueError('compressed byte limit exceeded')
                chunk = exact(stream, size)
                out.write(chunk)
                digest.update(chunk)
                count += size
            out.flush()
            os.fsync(out.fileno())
        line = stream.readline(513)
        if not line.endswith(b'\n') or len(line) > 512:
            raise ValueError('missing or oversized sender commit')
        commit = json.loads(line)
        if commit != {'sha256': digest.hexdigest(), 'bytes': count} or not count:
            raise ValueError('checksum/size mismatch')
        if stream.read(1):
            raise ValueError('trailing protocol bytes')
        verify(datafd, kind)
        stamp = datetime.datetime.now(datetime.timezone.utc)
        label = 'snapshot-' + stamp.strftime('%Y%m%dT%H%M%S%fZ-') + uuid.uuid4().hex
        receipt = {'verifiedAt': stamp.strftime('%Y-%m-%dT%H:%M:%SZ'),
                   'checksum': digest.hexdigest(), 'label': dataset + '/' + label,
                   'bytes': count, 'kind': kind}
        manifestfd = os.open('manifest.json', os.O_WRONLY | os.O_CREAT | os.O_EXCL | FILE, 0o600, dir_fd=stagefd)
        with os.fdopen(manifestfd, 'w') as manifest:
            json.dump(receipt, manifest)
            manifest.write('\n')
            manifest.flush()
            os.fsync(manifest.fileno())
        os.fsync(stagefd)
        os.rename(stage, label, src_dir_fd=parent, dst_dir_fd=parent)
        stage = None
        os.fsync(parent)
        snapshots = sorted(name for name in os.listdir(parent)
                           if re.fullmatch(r'snapshot-\d{8}T\d{12}Z-[0-9a-f]{32}', name))
        for name in snapshots[:-KEEP]:
            remove_snapshot(parent, name)
        os.fsync(parent)
        return receipt
    finally:
        if datafd is not None:
            os.close(datafd)
        if stagefd is not None:
            os.close(stagefd)
        if stage is not None:
            remove_snapshot(parent, stage)
        for fd in (lockfd, parent, rootfd):
            if fd is not None:
                os.close(fd)


def download(root, dataset, output):
    if dataset not in DATASETS:
        raise ValueError('dataset not allowed')
    rootfd = open_root(root)
    parent = lockfd = snapshotfd = datafd = None
    try:
        parent = os.open(dataset, DIRECTORY, dir_fd=rootfd)
        lockfd = os.open('.lock', os.O_RDWR | FILE, dir_fd=parent)
        fcntl.flock(lockfd, fcntl.LOCK_SH)
        names = sorted(n for n in os.listdir(parent)
                       if re.fullmatch(r'snapshot-\d{8}T\d{12}Z-[0-9a-f]{32}', n))
        if not names:
            raise ValueError('no successful snapshot')
        snapshotfd = os.open(names[-1], DIRECTORY, dir_fd=parent)
        manifestfd = os.open('manifest.json', os.O_RDONLY | FILE, dir_fd=snapshotfd)
        with os.fdopen(manifestfd) as source:
            receipt = json.load(source)
        output.write(json.dumps(receipt).encode() + b'\n')
        datafd = os.open('data.gz', os.O_RDONLY | FILE, dir_fd=snapshotfd)
        if not stat.S_ISREG(os.fstat(datafd).st_mode):
            raise ValueError('invalid snapshot file')
        while True:
            chunk = os.read(datafd, MAX_FRAME)
            if not chunk:
                break
            output.write(chunk)
        output.flush()
    finally:
        for fd in (datafd, snapshotfd, lockfd, parent, rootfd):
            if fd is not None:
                os.close(fd)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--root', default=ROOT)
    args = parser.parse_args()
    os.umask(0o077)
    # Total wall-clock cap bounds stalled SSH and NAS verification work.
    def expired(signum, frame):
        raise TimeoutError('receiver exceeded 6 hours')
    signal.signal(signal.SIGALRM, expired)
    signal.signal(signal.SIGTERM, expired)
    signal.alarm(6 * 3600)
    try:
        resource_limits(args.root)
        command = os.environ.get('SSH_ORIGINAL_COMMAND', '')
        match = re.fullmatch(r'download ([a-z-]+)', command)
        if match:
            download(args.root, match[1], sys.stdout.buffer)
            return 0
        receipt = receive(args.root, command, sys.stdin.buffer)
        print(json.dumps(receipt), flush=True)
    except Exception as error:
        print('nas-backup: ' + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
