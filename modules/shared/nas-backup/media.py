"""Export S3 objects as a streaming tar.gz, without a local media mirror."""
import json
import os
import subprocess
import sys
import tarfile

# Credentials are supplied by the unit, never by an interactive rclone profile.
os.environ['RCLONE_CONFIG'] = '/dev/null'
source = 'openpost:' + os.environ['OPENPOST_BACKUP_S3_BUCKET']
# S3's server timestamp detects writes without a metadata request for every object.
listing = ['rclone', 'lsjson', '--recursive', '--files-only', '--fast-list',
           '--no-mimetype', '--use-server-modtime', source]
objects = json.loads(subprocess.check_output(listing))
with tarfile.open(fileobj=sys.stdout.buffer, mode='w|gz') as archive:
    for item in objects:
        name = item['Path']
        if name.startswith('/') or '..' in name.split('/'):
            raise ValueError('unsafe object path')
        member = tarfile.TarInfo('media/' + name)
        member.size = item['Size']
        member.mode = 0o600
        reader = subprocess.Popen(['rclone', 'cat', source + '/' + name], stdout=subprocess.PIPE)
        try:
            archive.addfile(member, reader.stdout)
            if reader.stdout.read(1) or reader.wait() != 0:
                raise RuntimeError('object changed size or download failed: ' + name)
        finally:
            reader.stdout.close()
            if reader.poll() is None:
                reader.kill()
            reader.wait()
# Abort rather than publish an object set that changed while it was copied.
after = json.loads(subprocess.check_output(listing))
key = lambda rows: sorted((x['Path'], x['Size'], x['ModTime']) for x in rows)
if key(objects) != key(after):
    raise RuntimeError('media object set changed during backup; retry later')
