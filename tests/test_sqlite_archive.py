"""Exercise the archive CLI with real SQLite locks and restore its output."""
import io
import os
from pathlib import Path
import sqlite3
import subprocess
import sys
import tarfile
import tempfile
import threading
import unittest


ARCHIVER = Path(__file__).resolve().parents[1] / "modules/shared/nas-backup/sqlite_archive.py"


class SQLiteArchiveTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name).resolve()
        self.database = self.root / "data.db"
        self.writer = sqlite3.connect(self.database, timeout=0.2, check_same_thread=False)
        self.addCleanup(self.writer.close)
        self.writer.execute("CREATE TABLE entries (id INTEGER PRIMARY KEY, value TEXT)")
        self.writer.execute("INSERT INTO entries VALUES (1, 'committed')")
        self.writer.commit()

    def archive(self, *arguments):
        return subprocess.run(
            [sys.executable, str(ARCHIVER), str(self.root), "data.db", *arguments],
            capture_output=True, timeout=12,
        )

    def assert_restore(self, payload, expected=None):
        with tarfile.open(fileobj=io.BytesIO(payload), mode="r:gz") as archive:
            sql = b"".join(archive.extractfile(name).read() for name in sorted(archive.getnames())
                           if name.startswith("database/"))
            self.assertFalse(any(name.startswith("files/data.db") for name in archive.getnames()))
        with sqlite3.connect(":memory:") as restored:
            restored.executescript(sql.decode())
            self.assertEqual(restored.execute("PRAGMA integrity_check").fetchall(), [("ok",)])
            self.assertEqual(restored.execute("SELECT * FROM entries").fetchall(),
                             expected if expected is not None else [(1, "committed")])

    def test_slow_archive_consumer_does_not_block_application_writes(self):
        # An unconsumed upload fills the stdout pipe, just like a slow NAS.
        (self.root / "upload.bin").write_bytes(os.urandom(2 * 1024 * 1024))
        process = subprocess.Popen(
            [sys.executable, str(ARCHIVER), str(self.root), "data.db"],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, bufsize=0,
        )
        try:
            prefix = process.stdout.read(1)
            self.assertTrue(prefix)
            self.assertIsNone(process.poll())
            self.writer.execute("UPDATE entries SET value = 'after snapshot'")
            self.writer.commit()
            remaining, error = process.communicate(timeout=10)
            self.assertEqual(process.returncode, 0, error)
            self.assert_restore(prefix + remaining)
        finally:
            if process.poll() is None:
                process.kill()
            process.communicate()

    def test_committed_wal_rows_are_restored_without_uncommitted_rows(self):
        self.writer.execute("PRAGMA journal_mode=WAL")
        self.writer.execute("UPDATE entries SET value = 'committed in WAL'")
        self.writer.commit()
        self.writer.execute("BEGIN IMMEDIATE")
        self.writer.execute("INSERT INTO entries VALUES (2, 'uncommitted')")
        result = self.archive()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assert_restore(result.stdout, [(1, "committed in WAL")])

    def test_writer_releasing_after_old_five_second_timeout(self):
        self.writer.execute("BEGIN EXCLUSIVE")
        release = threading.Timer(6, self.writer.commit)
        release.start()
        try:
            result = self.archive()
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assert_restore(result.stdout)
        finally:
            release.join()

    def test_permanent_exclusive_lock_fails_before_streaming(self):
        self.writer.execute("PRAGMA locking_mode=EXCLUSIVE")
        self.writer.execute("UPDATE entries SET value = 'held'")
        self.writer.commit()
        result = subprocess.run(
            [sys.executable, str(ARCHIVER), str(self.root), "data.db", "--snapshot-timeout", "0.3"],
            capture_output=True, timeout=2,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, b"")
        self.assertIn(b"SQLite snapshot timed out", result.stderr)


if __name__ == "__main__":
    unittest.main()
