#!/usr/bin/python3
"""Read-only SSH transport, scoped to the radio library."""
import os
import re
import shlex
import shutil
import sys
from pathlib import Path
ROOT = Path('/volume1/homes/kraktoos/openpost-radio-music').resolve()
args = shlex.split(os.environ.get('SSH_ORIGINAL_COMMAND', ''))
if len(args) != 2 or args[0] != 'read':
    sys.exit(126)
name = args[1]
if not re.fullmatch(r'catalog\.json|tracks/[a-z0-9-]+\.flac|programmes/current\.json|programmes/[a-z0-9-]+/chunk-\d{5}\.ts', name):
    sys.exit(126)
path = (ROOT / name).resolve()
if ROOT not in path.parents or not path.is_file():
    sys.exit(1)
with path.open('rb') as audio:
    shutil.copyfileobj(audio, sys.stdout.buffer, 128 * 1024)
