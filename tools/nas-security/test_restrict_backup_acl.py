"""Native DSM recovery regression. Uses disposable folders and real ACL tools."""
import importlib.util
import json
from pathlib import Path
import shutil
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('repair', Path(__file__).with_name('restrict-backup-acl.py'))
repair = importlib.util.module_from_spec(spec)
spec.loader.exec_module(repair)


@unittest.skipUnless(Path(repair.TOOL).exists(), 'requires native DSM ACL tools')
class Recovery(unittest.TestCase):
    def test_missing_late_target_leaves_all_live_acl_policies_unchanged(self):
        base = Path(tempfile.mkdtemp(prefix='.rgo-acl-rollback-test.', dir=str(repair.HOME)))
        previous = repair.HOME, repair.BACKUPS, repair.JOURNALS
        try:
            repair.HOME = base
            repair.BACKUPS = base / 'Backups/rgo-vps'
            repair.JOURNALS = base / 'journals'
            for name in ['Development', 'University', 'Backups/rgo-vps', 'journals/policy']:
                (base / name).mkdir(parents=True, exist_ok=True)
            parent = repair.Object(base)
            try:
                parent.private()
                parent.add('user:sc-syncthing', repair.FULL)
            finally:
                parent.close()
            data = repair.BACKUPS / 'fixture'
            data.write_bytes(b'restore regression payload')
            journal = repair.JOURNALS / 'policy'
            repair.reconcile(base, repair.BACKUPS, journal, effective=False)
            records = json.loads((journal / 'manifest.json').read_text())

            def policies():
                result = {}
                for record in records:
                    if not Path(record['path']).exists():
                        continue
                    item = repair.Object(record['path'])
                    try:
                        result[record['path']] = item.read()[0]
                    finally:
                        item.close()
                return result

            retained = base / 'retained-inode'
            data.rename(retained)
            before = policies()
            with self.assertRaises(FileNotFoundError):
                repair.rollback(journal)
            self.assertEqual(policies(), before, 'rollback broadened ACLs before discovering missing data')
            retained.rename(data)
            repair.rollback(journal)
            self.assertEqual(policies(), {r['path']: r['text'] for r in records})
            self.assertEqual(data.read_bytes(), b'restore regression payload')
        finally:
            repair.HOME, repair.BACKUPS, repair.JOURNALS = previous
            shutil.rmtree(str(base))


if __name__ == '__main__':
    unittest.main()
