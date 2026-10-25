#!/usr/bin/env python3
"""Publish verified sender receipts and check backup freshness, never restore health."""
import argparse
import datetime
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
import tempfile


MAX_RECEIPT_BYTES = 4096
MAX_AGE = datetime.timedelta(hours=36)
UTC = datetime.timezone.utc


def dataset_name(value):
    if not re.fullmatch(r'[a-z][a-z0-9-]{0,63}', value):
        raise ValueError('invalid dataset name')
    return value


def private_directory(root):
    info = root.lstat()
    if (not stat.S_ISDIR(info.st_mode) or info.st_uid != os.geteuid()
            or stat.S_IMODE(info.st_mode) & 0o077):
        raise ValueError('receipt directory must be private and owned by the service user')


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError('duplicate receipt field')
        result[key] = value
    return result


def validate(raw, dataset, kind):
    if len(raw) > MAX_RECEIPT_BYTES:
        raise ValueError('oversized receipt')
    try:
        receipt = json.loads(raw, object_pairs_hook=unique_object)
    except (ValueError, UnicodeError, RecursionError):
        raise ValueError('malformed receipt') from None
    if (not isinstance(receipt, dict) or set(receipt) != {
            'verifiedAt', 'checksum', 'label', 'bytes', 'kind'}):
        raise ValueError('invalid receipt fields')
    if (receipt['kind'] != kind
            or not isinstance(receipt['checksum'], str)
            or not re.fullmatch(r'[a-f0-9]{64}', receipt['checksum'])
            or type(receipt['bytes']) is not int
            or not 0 < receipt['bytes'] <= 16 * 1024 ** 3
            or not isinstance(receipt['label'], str)
            or not re.fullmatch(re.escape(dataset) + r'/snapshot-\d{8}T\d{12}Z-[a-f0-9]{32}',
                                receipt['label'])):
        raise ValueError('receipt does not match dataset metadata')
    stamp = receipt['verifiedAt']
    if not isinstance(stamp, str) or not re.fullmatch(r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z', stamp):
        raise ValueError('invalid receipt timestamp')
    try:
        verified = datetime.datetime.strptime(stamp, '%Y-%m-%dT%H:%M:%SZ').replace(tzinfo=UTC)
    except ValueError:
        raise ValueError('invalid receipt timestamp') from None
    age = datetime.datetime.now(UTC) - verified
    if age < datetime.timedelta(0):
        raise ValueError('future receipt timestamp')
    if age > MAX_AGE:
        raise ValueError('stale receipt (older than 36 hours)')
    return receipt


def read_receipt(path):
    # Nonblocking open also makes a substituted FIFO fail without waiting.
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    with os.fdopen(fd, 'rb') as source:
        info = os.fstat(source.fileno())
        if (not stat.S_ISREG(info.st_mode) or info.st_uid != os.geteuid()
                or stat.S_IMODE(info.st_mode) & 0o077):
            raise ValueError('receipt must be a private regular file')
        return source.read(MAX_RECEIPT_BYTES + 1)


def record(root, dataset, kind, command):
    if not command:
        raise ValueError('sender command required')
    # The sender already checks producer exit and remote digest/size agreement.
    # Reading stdout alone is insufficient: a later failed exit cannot publish.
    with subprocess.Popen(command, stdout=subprocess.PIPE) as sender:
        raw = sender.stdout.read(MAX_RECEIPT_BYTES + 1)
        if len(raw) > MAX_RECEIPT_BYTES:
            sender.terminate()
            raise ValueError('oversized sender receipt')
        if sender.wait() != 0:
            raise ValueError('sender failed; previous receipt retained')
    receipt = validate(raw, dataset, kind)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode='w', dir=root, prefix='.' + dataset + '-',
                                         delete=False) as output:
            temporary = output.name
            os.fchmod(output.fileno(), 0o600)
            json.dump(receipt, output, sort_keys=True)
            output.write('\n')
            output.flush()
            os.fsync(output.fileno())
        os.replace(temporary, root / (dataset + '.json'))
        directory = os.open(root, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(directory)
        finally:
            os.close(directory)
    finally:
        if temporary is not None:
            Path(temporary).unlink(missing_ok=True)
    print(dataset + ': verified backup receipt published; restore drills separate')


def check(root, expected):
    failed = False
    for entry in expected:
        dataset, separator, kind = entry.partition(':')
        dataset_name(dataset)
        if not separator or kind not in ('gzip', 'tar-gzip'):
            raise ValueError('expected dataset:kind required')
        try:
            validate(read_receipt(root / (dataset + '.json')), dataset, kind)
        except FileNotFoundError:
            print(dataset + ': missing receipt', file=sys.stderr)
            failed = True
        except OSError:
            print(dataset + ': unreadable or unsafe receipt', file=sys.stderr)
            failed = True
        except ValueError as error:
            print(dataset + ': ' + str(error), file=sys.stderr)
            failed = True
    if failed:
        return 1
    print('Backup receipts fresh for ' + str(len(expected)) +
          ' enabled datasets; restore drills not evaluated')
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--state-dir', type=Path, required=True)
    commands = parser.add_subparsers(dest='action', required=True)
    publish = commands.add_parser('record')
    publish.add_argument('dataset', type=dataset_name)
    publish.add_argument('kind', choices=('gzip', 'tar-gzip'))
    publish.add_argument('command', nargs=argparse.REMAINDER)
    monitor = commands.add_parser('check')
    monitor.add_argument('datasets', nargs='+')
    args = parser.parse_args()
    if args.action == 'record':
        args.state_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
    private_directory(args.state_dir)
    if args.action == 'record':
        command = args.command[1:] if args.command[:1] == ['--'] else args.command
        record(args.state_dir, args.dataset, args.kind, command)
        return 0
    return check(args.state_dir, args.datasets)


if __name__ == '__main__':
    try:
        sys.exit(main())
    except OSError:
        print('nas-backup-freshness: receipt I/O failed', file=sys.stderr)
        sys.exit(1)
    except ValueError as error:
        print('nas-backup-freshness: ' + str(error), file=sys.stderr)
        sys.exit(1)
