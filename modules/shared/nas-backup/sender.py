#!/usr/bin/env python3
"""Stream a pipefail producer to the forced receiver; no local dump file."""
import hashlib
import json
import os
import signal
import socket
import struct
import subprocess
import sys


def send(dataset, kind, command):
    try:
        socket.getaddrinfo('rgo-nas', 22)
        host = 'rgo-nas'
    except socket.gaierror:
        host = '100.88.5.41'
    ssh = ['ssh', '-T', '-oBatchMode=yes', '-oIdentitiesOnly=yes',
           '-oStrictHostKeyChecking=yes', '-oUserKnownHostsFile=/etc/nas-backup/known_hosts',
           '-oGlobalKnownHostsFile=/dev/null', '-oHostKeyAlias=rgo-nas', '-oHostKeyAlgorithms=ssh-ed25519',
           '-oConnectTimeout=30', '-oServerAliveInterval=30', '-oServerAliveCountMax=3',
           '-i', os.environ.get('NAS_BACKUP_SSH_KEY', '/var/lib/nas-backup/id_ed25519'), 'kraktoos@' + host,
           'upload ' + dataset + ' ' + kind]
    remote = subprocess.Popen(ssh, stdin=subprocess.PIPE, stdout=subprocess.PIPE)
    producer = subprocess.Popen(['bash', '-euo', 'pipefail', '-c', command], stdout=subprocess.PIPE,
                                start_new_session=True)
    digest = hashlib.sha256()
    count = 0
    try:
        while True:
            chunk = producer.stdout.read(1024 * 1024)
            if not chunk:
                break
            remote.stdin.write(struct.pack('!I', len(chunk)))
            remote.stdin.write(chunk)
            digest.update(chunk)
            count += len(chunk)
        # gzip can emit a valid trailer even when pg_dump failed. Never send a
        # success token just because the compressed stream ended normally.
        if producer.wait() != 0:
            raise RuntimeError('backup producer failed; remote commit withheld')
        remote.stdin.write(struct.pack('!I', 0))
        remote.stdin.write(json.dumps({'sha256': digest.hexdigest(), 'bytes': count}).encode() + b'\n')
        remote.stdin.close()
        receipt = remote.stdout.read(4097)
        if len(receipt) > 4096 or remote.wait() != 0:
            raise RuntimeError('NAS verification failed')
        parsed = json.loads(receipt)
        if (parsed['checksum'] != digest.hexdigest() or parsed['bytes'] != count
                or parsed['kind'] != kind or not parsed['label'].startswith(dataset + '/snapshot-')):
            raise RuntimeError('NAS receipt does not match source stream')
        print(json.dumps(parsed), flush=True)
    finally:
        if producer.poll() is None:
            os.killpg(producer.pid, signal.SIGTERM)
            try:
                producer.wait(timeout=10)
            except subprocess.TimeoutExpired:
                os.killpg(producer.pid, signal.SIGKILL)
                producer.wait()
        if not remote.stdin.closed:
            try:
                remote.stdin.close()
            except BrokenPipeError:
                pass
        if remote.poll() is None:
            remote.terminate()
            try:
                remote.wait(timeout=10)
            except subprocess.TimeoutExpired:
                remote.kill()
                remote.wait()


if __name__ == '__main__':
    try:
        send(*sys.argv[1:])
    except Exception as error:
        print('nas-backup: ' + str(error), file=sys.stderr)
        sys.exit(1)
