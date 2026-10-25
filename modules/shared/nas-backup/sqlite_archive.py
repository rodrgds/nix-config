"""Stream SQLite SQL chunks and app files. Concatenate database/*.sql to restore."""
import argparse
from contextlib import closing
import io
import os
from pathlib import Path
import stat
import sqlite3
import sys
import tarfile
import tempfile
import time

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("root", type=Path)
parser.add_argument("database")
parser.add_argument("--snapshot-timeout", type=float, default=30,
                    help="maximum seconds to acquire a consistent SQLite snapshot")
args = parser.parse_args()
if not 0 < args.snapshot_timeout < float("inf"):
    parser.error("snapshot timeout must be positive and finite")
root = args.root.resolve()
database = root / args.database
if not database.is_file():
    raise RuntimeError("missing database")

# Never hold a live read transaction while streaming to a potentially slow NAS.
# The online backup API includes committed WAL pages and retries busy writers.
# A permanent pending/exclusive lock still fails closed, before emitting bytes.
with tempfile.TemporaryDirectory(prefix="sqlite-archive-") as temporary:
    snapshot = Path(temporary) / "snapshot.sqlite"
    deadline = time.monotonic() + args.snapshot_timeout

    def progress(status, remaining, total):
        if time.monotonic() >= deadline:
            raise TimeoutError("SQLite snapshot timed out; application may hold a persistent lock")

    with closing(sqlite3.connect(snapshot)) as db:
        source = sqlite3.connect(database.as_uri() + "?mode=ro", uri=True, timeout=0.1)
        try:
            source.backup(db, pages=256, progress=progress, sleep=0.1)
        finally:
            source.close()
        integrity = db.execute("PRAGMA integrity_check").fetchall()
        if integrity != [("ok",)]:
            raise RuntimeError("SQLite integrity check failed")
        with tarfile.open(fileobj=sys.stdout.buffer, mode="w|gz") as archive:
            chunk = bytearray()
            index = 0
            def emit():
                global index
                member = tarfile.TarInfo(f"database/{index:08d}.sql")
                member.size = len(chunk)
                member.mode = 0o600
                archive.addfile(member, io.BytesIO(chunk))
                index += 1
                chunk.clear()
            for line in db.iterdump():
                data = (line + "\n").encode()
                for offset in range(0, len(data), 1024 * 1024):
                    chunk.extend(data[offset:offset + 1024 * 1024])
                    if len(chunk) >= 1024 * 1024:
                        emit()
            if chunk:
                emit()
            excluded = {database, *(Path(str(database) + suffix) for suffix in ("-wal", "-shm", "-journal"))}
            for directory, dirs, files in os.walk(root, followlinks=False):
                for name in sorted(dirs + files):
                    path = Path(directory) / name
                    if path in excluded:
                        continue
                    if path.is_symlink():
                        raise RuntimeError("symlink in application data: " + str(path))
                    before = path.stat()
                    if not (stat.S_ISREG(before.st_mode) or stat.S_ISDIR(before.st_mode)):
                        raise RuntimeError("special file in application data: " + str(path))
                    archive.add(path, arcname="files/" + str(path.relative_to(root)), recursive=False)
                    after = path.stat()
                    if (before.st_size, before.st_mtime_ns) != (after.st_size, after.st_mtime_ns):
                        raise RuntimeError("file changed during backup: " + str(path))
