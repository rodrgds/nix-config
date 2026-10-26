#!/usr/bin/python3
"""Narrow DSM backup ACLs, retaining Syncthing's three configured roots.

Run --self-test first, then --apply as root on the NAS. Changes are journaled
outside the home tree and automatically rolled back on failed acceptance.
"""
import argparse
import fcntl
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import tempfile
import signal
import pwd
import xml.etree.ElementTree as ET

TOOL = '/usr/syno/bin/synoacltool'
HOME = Path('/volume1/homes/kraktoos')
BACKUPS = HOME / 'Backups' / 'rgo-vps'
JOURNALS = Path('/volume1/docker/rgo-security-acl')
FULL = 'rwxpdDaARWcCo'
ADMIN = 'rwxpdDaARWc--'
ENTRY = re.compile(r'^\s*\[(\d+)\] ((?:user|group|owner|everyone|authenticated_user|system):[^:]*:(?:allow|deny):[rwxpdDaARWcCo-]{13}:[fdin-]{4}) \(level:(\d+)\)\s*$')


class Object:
    def __init__(self, path, fd=None):
        self.path = Path(path)
        self.fd = os.open(str(path), os.O_RDONLY | os.O_NONBLOCK | os.O_NOFOLLOW) if fd is None else fd
        info = os.fstat(self.fd)
        if not (stat.S_ISDIR(info.st_mode) or stat.S_ISREG(info.st_mode)):
            raise ValueError('special file refused: ' + str(path))
        if stat.S_ISREG(info.st_mode) and info.st_nlink != 1:
            raise ValueError('hard-linked file refused: ' + str(path))
        self.directory = stat.S_ISDIR(info.st_mode)
        self.ref = '/proc/self/fd/' + str(self.fd)
        self.owner = (info.st_uid, info.st_gid)
        self.identity = (info.st_dev, info.st_ino)

    def call(self, operation, *args):
        result = subprocess.run([TOOL, operation, self.ref, *args],
                                pass_fds=(self.fd,), text=True, capture_output=True, timeout=10)
        if result.returncode:
            if operation == '-get' and "It's Linux mode" in result.stderr + result.stdout:
                return 'ACL version: Linux mode\nArchive: None\n'
            raise RuntimeError(operation + ' failed for ' + str(self.path) + ': ' + (result.stderr or result.stdout).strip())
        return result.stdout

    def read(self):
        text = self.call('-get')
        if not re.search(r'^ACL version: (?:\d+|No ACL|Linux mode)\s*$', text, re.M):
            raise ValueError('unrecognized ACL: ' + str(self.path))
        archive = re.search(r'^Archive:\s*(.*)$', text, re.M)
        if not archive:
            raise ValueError('missing ACL flags: ' + str(self.path))
        entries = []
        for line in text.splitlines():
            if line.lstrip().startswith('['):
                match = ENTRY.fullmatch(line)
                if not match:
                    raise ValueError('unrecognized ACL entry: ' + str(self.path))
                entries.append((int(match[1]), match[2], int(match[3])))
        return text, set(archive[1].replace(' ', '').split(',')), entries

    def is_private_linux(self):
        if not self.read()[0].startswith('ACL version: Linux mode'):
            return False
        info = os.fstat(self.fd)
        needed = 0o500 if self.directory else 0o400
        if (info.st_uid not in {0, pwd.getpwnam('kraktoos').pw_uid}
                or info.st_mode & 0o077 or info.st_mode & needed != needed):
            raise ValueError('legacy Linux-mode object needs permission review: ' + str(self.path))
        return True

    def add(self, identity, rights):
        entry = identity + ':allow:' + rights + (':fd--' if self.directory else ':----')
        if not any(value == entry and level == 0 for _, value, level in self.read()[2]):
            self.call('-add', entry)

    def private(self):
        for identity, rights in [('user:kraktoos', FULL), ('user:root', FULL), ('group:administrators', ADMIN)]:
            self.add(identity, rights)
        self.call('-del-archive', 'is_inherit')
        for index, entry, _ in reversed(self.read()[2]):
            if entry.split(':allow:')[0] not in {'user:kraktoos', 'user:root', 'group:administrators'}:
                self.call('-del', str(index))

    def remove_syncthing(self, detach=False):
        if detach:
            # Freeze the other existing parent grants before removing inherited
            # Syncthing authority. Do not change unrelated backup principals.
            entries = self.read()[2]
            local = {entry for _, entry, level in entries if level == 0}
            for _, entry, level in entries:
                if level and not entry.startswith('user:sc-syncthing:') and entry not in local:
                    argument = re.sub(r'^(owner|everyone)::', r'\1:*:', entry)
                    self.call('-add', argument)
                    local.add(entry)
            self.call('-del-archive', 'is_inherit')
        for index, entry, level in reversed(self.read()[2]):
            if entry.startswith('user:sc-syncthing:'):
                if level:
                    raise ValueError('Syncthing grant comes from a higher ancestor: ' + str(self.path))
                self.call('-del', str(index))

    def close(self):
        os.close(self.fd)


def inventory(root):
    result = []
    anchor = os.open(str(root), os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    device = os.fstat(anchor).st_dev
    try:
        for current, directories, files, parentfd in os.fwalk('.', dir_fd=anchor, follow_symlinks=False):
            for name in ['.'] + files:
                info = os.stat(name, dir_fd=parentfd, follow_symlinks=False)
                if info.st_dev != device or not (stat.S_ISDIR(info.st_mode) or stat.S_ISREG(info.st_mode)):
                    raise ValueError('unexpected filesystem object')
                fd = os.open(name, os.O_RDONLY | os.O_NONBLOCK | os.O_NOFOLLOW, dir_fd=parentfd)
                result.append(Object(root / current / ('' if name == '.' else name), fd))
            for name in directories:
                if stat.S_ISLNK(os.stat(name, dir_fd=parentfd, follow_symlinks=False).st_mode):
                    raise ValueError('symlink refused')
            if len(result) > 5000:
                raise ValueError('unexpected tree growth')
        return result
    except BaseException:
        for item in result:
            item.close()
        raise
    finally:
        os.close(anchor)


def permission(item, username):
    text = item.call('-get-perm', username)
    match = re.search(r'Final permission:\s*\[([rwxpdDaARWcCo-]*)\]', text)
    if not match:
        raise ValueError('effective permission inspection failed')
    return set(match[1]) - {'-'}


def rollback(journal):
    journal = journal.resolve(strict=True)
    if journal.parent != JOURNALS.resolve(strict=True) or os.stat(str(journal)).st_uid != os.geteuid():
        raise ValueError('rollback must use the root-owned saved policy directory')
    records = json.loads((journal / 'manifest.json').read_text())
    prepared = []
    opened = []
    try:
        # Validate the complete recovery set before restoring Home's old broad
        # grant. Retention or a missing snapshot must leave the live ACLs intact.
        for number, saved in enumerate(records):
            path = Path(saved['path'])
            if path not in {HOME, HOME / 'Backups', HOME / 'Development', HOME / 'University'} and path != BACKUPS and BACKUPS not in path.parents:
                raise ValueError('unexpected recovery path')
            snapshot_path = journal / str(number)
            if saved['snapshot'] != str(snapshot_path):
                raise ValueError('unexpected recovery object')
            item = Object(path)
            opened.append(item)
            snapshot = Object(snapshot_path)
            opened.append(snapshot)
            if list(item.identity) != saved['identity'] or list(item.owner) != saved['owner']:
                raise ValueError('recovery object was replaced or changed owner: ' + str(path))
            if item.directory != snapshot.directory or os.fstat(snapshot.fd).st_uid != os.geteuid():
                raise ValueError('unexpected recovery object type or owner')
            expected = {match[2] for line in saved['text'].splitlines()
                        if (match := ENTRY.fullmatch(line)) and match[3] == '0'}
            actual = {entry for _, entry, level in snapshot.read()[2] if level == 0}
            if expected != actual:
                raise ValueError('saved ACL object differs from its manifest')
            prepared.append((item, snapshot, saved))
        for item, snapshot, saved in prepared:
            if saved['acl']:
                subprocess.run([TOOL, '-copy', snapshot.ref, item.ref], pass_fds=(snapshot.fd, item.fd), check=True, stdout=subprocess.DEVNULL)
            else:
                item.call('-del')
            item.call('-set-archive' if saved['inherit'] else '-del-archive', 'is_inherit')
            if item.read()[0] != saved['text']:
                raise RuntimeError('restored policy differs: ' + str(item.path))
    finally:
        for item in opened:
            item.close()
    print('PASS: original ACLs restored from ' + str(journal))


def reconcile(home, backups, journal, effective=True):
    prefix = [Object(home), Object(home / 'Backups'), Object(home / 'Development'), Object(home / 'University')]
    all_objects = prefix + inventory(backups)
    objects = []
    snapshots = []
    changed = []
    try:
        # Old imports may use private Unix permissions without DSM ACL support.
        # Preserve those objects verbatim; never convert their format or modes.
        for item in all_objects:
            if item.is_private_linux():
                if item in prefix or item.path == backups:
                    raise ValueError('policy root must support DSM ACLs')
                continue
            objects.append(item)
        for number, item in enumerate(objects):
            text, flags, entries = item.read()
            if any(':deny:' in entry for _, entry, _ in entries) or 'is_read_only' in flags:
                raise ValueError('custom deny/read-only policy needs review: ' + str(item.path))
            snapshot = journal / str(number)
            (snapshot.mkdir if item.directory else snapshot.touch)()
            if entries:
                subprocess.run([TOOL, '-copy', item.ref, str(snapshot)], pass_fds=(item.fd,), check=True, stdout=subprocess.DEVNULL, timeout=10)
            saved_fd = os.open(str(snapshot), os.O_RDONLY | os.O_NOFOLLOW)
            try:
                os.fsync(saved_fd)
            finally:
                os.close(saved_fd)
            snapshots.append({'path': str(item.path), 'snapshot': str(snapshot), 'inherit': 'is_inherit' in flags, 'acl': bool(entries), 'identity': item.identity, 'owner': item.owner, 'text': text})
        # Every recovery object and original policy is saved before any mutation.
        with (journal / 'manifest.json').open('w') as manifest:
            os.fchmod(manifest.fileno(), 0o600)
            json.dump(snapshots, manifest, indent=2)
            manifest.flush()
            os.fsync(manifest.fileno())
        journal_fd = os.open(str(journal), os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
        try:
            os.fsync(journal_fd)
        finally:
            os.close(journal_fd)
        for item in prefix[2:]:
            changed.append(item)
            item.add('user:sc-syncthing', FULL)
        for item in prefix[:2]:
            changed.append(item)
            item.remove_syncthing(detach=item is prefix[1])
            if item is prefix[0]:
                # Permit reaching the explicit Development/University roots,
                # without home-wide read, write, delete or ACL authority.
                entry = 'user:sc-syncthing:allow:--x----------:----'
                if not any(value == entry and level == 0 for _, value, level in item.read()[2]):
                    item.call('-add', entry)
        for item in objects[4:]:
            changed.append(item)
            item.private()
        for item in objects[4:]:
            _, flags, entries = item.read()
            assert 'is_inherit' not in flags
            assert all(entry.split(':allow:')[0] in {'user:kraktoos', 'user:root', 'group:administrators'} for _, entry, _ in entries)
            assert item.owner == (os.fstat(item.fd).st_uid, os.fstat(item.fd).st_gid)
        if effective:
            for item in prefix[:2] + [objects[4]]:
                assert not (permission(item, 'sc-syncthing') & set('rwpdDAWCo')), str(item.path)
            for item in prefix[2:]:
                assert set(FULL) <= permission(item, 'sc-syncthing'), str(item.path)
            assert set(FULL) <= permission(objects[4], 'kraktoos')
        for item in all_objects:
            if item not in objects:
                assert item.is_private_linux()
        (journal / 'SUCCESS').write_text('ACL acceptance passed. No data or firewall was changed.\n')
        print('PASS: preserved sync roots, removed broad Syncthing authority, private backup ACLs; journal=' + str(journal))
    except BaseException:
        if changed:
            # Restore parents before descendants, including original inheritance.
            for item, saved in zip(objects, snapshots):
                if item not in changed:
                    continue
                if saved['acl']:
                    subprocess.run([TOOL, '-copy', saved['snapshot'], item.ref], pass_fds=(item.fd,), check=True, stdout=subprocess.DEVNULL)
                else:
                    item.call('-del')
                item.call('-set-archive' if saved['inherit'] else '-del-archive', 'is_inherit')
                if item.read()[0] != saved['text']:
                    raise RuntimeError('rollback needs review: ' + str(item.path) + '; journal=' + str(journal))
            print('Original ACLs restored; journal=' + str(journal))
        raise
    finally:
        for item in all_objects:
            item.close()


def self_test():
    temporary = Path(tempfile.mkdtemp(prefix='.rgo-acl-self-test.', dir=str(HOME)))
    items = []
    try:
        item = Object(temporary)
        items.append(item)
        item.private()
        item.add('user:sc-syncthing', FULL)
        for name in ['Development', 'University', 'Backups/rgo-vps']:
            (temporary / name).mkdir(parents=True, exist_ok=True)
        data = temporary / 'Backups/rgo-vps/fixture'
        data.write_bytes(b'synthetic ACL regression')
        before = Object(data)
        items.append(before)
        assert any('sc-syncthing' in entry for _, entry, _ in before.read()[2]), 'baseline exposure not reproduced'
        journal = temporary / 'journal'
        journal.mkdir()
        reconcile(temporary, temporary / 'Backups/rgo-vps', journal, effective=os.geteuid() == 0)
        assert data.read_bytes() == b'synthetic ACL regression'
        if os.geteuid() == 0:
            account = pwd.getpwnam('sc-syncthing')
            def demote():
                os.initgroups(account.pw_name, account.pw_gid)
                os.setgid(account.pw_gid)
                os.setuid(account.pw_uid)
            for path, allowed in [(data, False), (temporary / 'Development', True), (temporary / 'University', True)]:
                result = subprocess.run(['/bin/test', '-r', str(path)], preexec_fn=demote)
                assert result.returncode in {0, 1}
                assert (result.returncode == 0) == allowed, str(path)
            for path in [temporary / 'Development', temporary / 'University']:
                result = subprocess.run(['/usr/bin/python3', '-c',
                    'import pathlib,sys; p=pathlib.Path(sys.argv[1])/"ordinary-write"; p.write_bytes(b"fixture"); p.unlink()', str(path)], preexec_fn=demote)
                assert result.returncode == 0
        print('PASS: real DSM baseline exposure reproduced, repaired, payload preserved')
    finally:
        for item in items:
            item.close()
        shutil.rmtree(str(temporary))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    actions = parser.add_mutually_exclusive_group(required=True)
    actions.add_argument('--self-test', action='store_true')
    actions.add_argument('--apply', action='store_true')
    actions.add_argument('--rollback', type=Path)
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return
    if os.geteuid() != 0:
        parser.error('--apply requires the administrator\'s own sudo authentication')
    status = subprocess.run(['/usr/syno/bin/synopkg', 'status', 'syncthing'], capture_output=True, text=True)
    if json.loads(status.stdout).get('status') != 'stop':
        parser.error('Syncthing must remain stopped during this maintenance')
    if not args.rollback:
        folders = {folder.get('path') for folder in ET.parse('/var/packages/syncthing/var/config.xml').getroot().findall('folder')}
        if folders != {str(HOME / 'Development'), str(HOME / 'University'), '/volume1/jdsystem'}:
            parser.error('Syncthing folder configuration changed; review required')
    def interrupted(signum, frame):
        raise RuntimeError('interrupted by signal ' + str(signum))
    for signum in [signal.SIGTERM, signal.SIGHUP]:
        signal.signal(signum, interrupted)
    if not args.rollback:
        self_test()
    JOURNALS.mkdir(mode=0o700, exist_ok=True)
    journal_root = Object(JOURNALS)
    journal_root.private()
    journal_root.close()
    with (JOURNALS / '.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        locks = []
        try:
            for name in ['directus', 'montra-db', 'openpost-db', 'openpost-media', 'shlink-db', 'umami-db', 'unprompted-db', 'vaultwarden']:
                fd = os.open(str(BACKUPS / name / '.lock'), os.O_RDWR | os.O_NOFOLLOW)
                locks.append(fd)
                fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            if args.rollback:
                rollback(args.rollback)
                return
            journal = Path(tempfile.mkdtemp(prefix='policy-', dir=str(JOURNALS)))
            reconcile(HOME, BACKUPS, journal)
        finally:
            for fd in locks:
                os.close(fd)


if __name__ == '__main__':
    main()
