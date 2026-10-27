"""Install only the owned read-only receiver and append its restricted key."""
from pathlib import Path
import os
import shutil
root = Path('/host-lib/openpost-radio')
root.mkdir(mode=0o755, exist_ok=True)
target = root / 'library-read.py'
shutil.copyfile('/input/library-read.py', target)
os.chmod(target, 0o755)
key = Path('/input/id_ed25519.pub').read_text().strip()
if not key.startswith('ssh-ed25519 ') or '\n' in key:
    raise ValueError('invalid public key')
line = 'restrict,command="/usr/local/lib/openpost-radio/library-read.py" ' + key
path = Path('/keys/kraktoos')
existing = path.read_text()
if line not in existing.splitlines():
    with path.open('a') as out:
        out.write(('' if existing.endswith('\n') else '\n') + line + '\n')
