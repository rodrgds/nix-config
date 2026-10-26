"""ACL metadata acceptance against observed DSM output, without NAS mutations."""

import contextlib
import importlib.util
import io
from pathlib import Path
import subprocess
import tempfile
import unittest
import os
from types import SimpleNamespace
from unittest.mock import patch


spec = importlib.util.spec_from_file_location(
    "verify_backup_acl", Path(__file__).with_name("verify-backup-acl.py")
)
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)

PRIVATE = """ACL version: 1
Archive: is_support_ACL
Owner: [root(user)]
---------------------
 [0] user:kraktoos:allow:rwxpdDaARWcCo:fd-- (level:0)
 [1] group:administrators:allow:rwxpdDaARWc--:fd-- (level:0)
"""


class BackupAclTest(unittest.TestCase):
    def test_linux_mode_legacy_archive_requires_private_actual_mode(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            data = root / 'legacy.tar'
            data.write_bytes(b'fixture payload is not read by the verifier')
            for mode, error, expected in [
                (0o600, "It's Linux mode", 0),
                (0o640, "It's Linux mode", 1),
                (0o600, 'unrecognized tool failure', 1),
            ]:
                data.chmod(mode)
                def metadata(command, **kwargs):
                    return (subprocess.CompletedProcess(command, 255, '', error)
                            if Path(command[-1]) == data else subprocess.CompletedProcess(command, 0, PRIVATE, ''))
                with self.subTest(mode=oct(mode), error=error):
                    identity = SimpleNamespace(getpwnam=lambda _: SimpleNamespace(pw_uid=os.getuid()))
                    with patch.object(audit.subprocess, 'run', side_effect=metadata), patch.object(audit, 'pwd', identity, create=True):
                        with contextlib.redirect_stdout(io.StringIO()):
                            self.assertEqual(audit.main([str(root)]), expected)

    def test_entire_subtree_requires_private_recognized_metadata(self):
        inherited = PRIVATE.replace("Archive: is_support_ACL", "Archive: is_inherit,is_support_ACL")
        syncthing = inherited + " [2] user:sc-syncthing:allow:rwxpdDaARWcCo:fd-- (level:2)\n"
        cases = [
            ("private", PRIVATE, inherited, 0, 0),
            ("inherited-root", inherited, inherited, 0, 1),
            ("deep-file-exposure", PRIVATE, syncthing, 0, 1),
            ("unrecognized-output", PRIVATE, "unknown format\n", 0, 1),
            ("broad-deny", PRIVATE, inherited + " [2] everyone::deny:rwxpdDaARWcCo:fd-- (level:0)\n", 0, 1),
            ("failed-tool", PRIVATE, PRIVATE, 255, 1),
        ]
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            dataset = root / "directus" / "snapshot"
            dataset.mkdir(parents=True)
            data = dataset / "data.gz"
            data.write_bytes(b"fixture must never be opened")
            for name, root_acl, file_acl, tool_status, expected in cases:
                with self.subTest(name=name):
                    visited = []

                    def metadata(command, **kwargs):
                        visited.append(command[-1])
                        text = root_acl if Path(command[-1]) == root else inherited
                        if Path(command[-1]) == data:
                            text = file_acl
                        return subprocess.CompletedProcess(command, tool_status, text, "")

                    with patch.object(audit.subprocess, "run", side_effect=metadata):
                        with contextlib.redirect_stdout(io.StringIO()):
                            self.assertEqual(audit.main([str(root)]), expected)
                    self.assertEqual(set(visited), {str(root), str(root / "directus"), str(dataset), str(data)})

    def test_symlinks_are_rejected_without_following_them(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "backups"
            root.mkdir()
            outside = Path(directory) / "private"
            outside.mkdir()
            (root / "escape").symlink_to(outside, target_is_directory=True)
            with patch.object(audit.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, PRIVATE, "")) as tool:
                with contextlib.redirect_stdout(io.StringIO()):
                    self.assertEqual(audit.main([str(root)]), 1)
            self.assertEqual([call.args[0][-1] for call in tool.call_args_list], [str(root)])


if __name__ == "__main__":
    unittest.main()
