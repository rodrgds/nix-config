"""Retrieve the latest NAS snapshot, checksum it, and restore in ephemeral state."""
import gzip
import hashlib
import json
import os
from pathlib import Path
import re
import socket
import sqlite3
import subprocess
import sys
import tarfile
import tempfile


def fetch(dataset, destination):
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
            '-i', '/var/lib/nas-backup/id_ed25519', 'kraktoos@' + host,
            'download ' + dataset]
    remote = subprocess.Popen(args, stdout=subprocess.PIPE)
    try:
        line = remote.stdout.readline(4097)
        if not line.endswith(b'\n') or len(line) > 4096:
            raise ValueError('invalid NAS manifest')
        manifest = json.loads(line)
        if not re.fullmatch(re.escape(dataset) + r'/snapshot-\d{8}T\d{12}Z-[0-9a-f]{32}', manifest['label']):
            raise ValueError('incorrect snapshot identity')
        digest = hashlib.sha256()
        count = 0
        with open(destination, 'wb') as out:
            while True:
                chunk = remote.stdout.read(1024 * 1024)
                if not chunk:
                    break
                out.write(chunk)
                count += len(chunk)
                digest.update(chunk)
        if remote.wait() or count != manifest['bytes'] or digest.hexdigest() != manifest['checksum']:
            raise ValueError('NAS download checksum/size mismatch')
        return manifest
    finally:
        remote.stdout.close()
        if remote.poll() is None:
            remote.kill()
        remote.wait()


def sqlite_check(archive, directory):
    sql = []
    with tarfile.open(archive, 'r:gz') as source:
        for member in source:
            if member.name.startswith('/') or '..' in member.name.split('/') or not (member.isfile() or member.isdir()):
                raise ValueError('unsafe archive')
            if re.fullmatch(r'database/\d{8}\.sql', member.name):
                sql.append(member.name)
        if not sql or len(set(sql)) != len(sql):
            raise ValueError('missing or duplicate SQL chunks')
        restored = Path(directory) / 'database.sqlite'
        proc = subprocess.Popen(['sqlite3', '-bail', str(restored)], stdin=subprocess.PIPE)
        try:
            for name in sorted(sql):
                with source.extractfile(name) as chunk:
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
        with sqlite3.connect(restored) as db:
            if db.execute('PRAGMA integrity_check').fetchone()[0] != 'ok':
                raise ValueError('SQLite restored integrity check failed')
            if not db.execute("SELECT count(*) FROM sqlite_master WHERE type='table'").fetchone()[0]:
                raise ValueError('empty restored database')


def openpost_check(archive, media):
    database = 'openpost_restore_drill_' + str(os.getpid())
    def run(*args, **kwargs):
        return subprocess.run(['podman', 'exec', 'openpost-postgres', *args], check=True, **kwargs)
    run('createdb', '-U', 'openpost', database)
    try:
        proc = subprocess.Popen(['podman', 'exec', '-i', 'openpost-postgres', 'psql', '-v',
                                 'ON_ERROR_STOP=1', '-U', 'openpost', '-d', database], stdin=subprocess.PIPE,
                                stdout=subprocess.DEVNULL)
        try:
            with gzip.open(archive, 'rb') as source:
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
            return int(run('psql', '-Atqc', query, '-U', 'openpost', '-d', database,
                           capture_output=True, text=True).stdout.strip())
        if count("SELECT count(*) FROM information_schema.tables WHERE table_schema='public'") < 10:
            raise ValueError('too few restored public tables')
        for table in ('users', 'workspaces', 'posts'):
            count('SELECT count(*) FROM ' + table)
        records = count('SELECT count(*) FROM media_attachments')
        with tarfile.open(media, 'r:gz') as source:
            files = sum(member.isfile() for member in source)
        if records and not files:
            raise ValueError('media records without media snapshot files')
    finally:
        run('dropdb', '--if-exists', '-U', 'openpost', database)


def main():
    os.umask(0o077)
    dataset = sys.argv[1]
    with tempfile.TemporaryDirectory(prefix='nas-restore-', dir=os.environ['RUNTIME_DIRECTORY']) as directory:
        archive = Path(directory) / 'data.gz'
        receipt = fetch(dataset, archive)
        if dataset == 'directus':
            sqlite_check(archive, directory)
        elif dataset == 'openpost-db':
            media = Path(directory) / 'media.gz'
            fetch('openpost-media', media)
            openpost_check(archive, media)
        else:
            raise ValueError('unsupported restore check')
        print(json.dumps({'status': 'passed', 'snapshot': receipt['label']}), flush=True)


if __name__ == '__main__':
    main()
