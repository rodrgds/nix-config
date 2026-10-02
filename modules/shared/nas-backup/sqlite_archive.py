"""Stream SQLite SQL chunks and app files. Concatenate database/*.sql to restore."""
import io
import os
from pathlib import Path
import stat
import sqlite3
import sys
import tarfile
root = Path(sys.argv[1])
database = root / sys.argv[2]
if not database.is_file():
    raise RuntimeError("missing database")
with sqlite3.connect(database.as_uri() + "?mode=ro", uri=True) as db:
    db.execute("BEGIN")
    if db.execute("PRAGMA integrity_check").fetchone()[0] != "ok":
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
