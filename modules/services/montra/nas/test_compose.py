"""Exercise Compose's service selection without contacting a Docker daemon."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


class ComposeSelectionTest(unittest.TestCase):
    def test_updater_requires_explicit_opt_in(self):
        with tempfile.TemporaryDirectory() as directory:
            fixture = Path(directory)
            shutil.copyfile(Path(__file__).with_name("compose.yaml"), fixture / "compose.yaml")
            (fixture / "worker.env").write_text("AUDIT_FIXTURE=true\n")
            env = {
                key: value
                for key, value in os.environ.items()
                if not key.startswith(("COMPOSE_", "CATALOG_WORKER_"))
            }
            env["DOCKER_HOST"] = "unix:///nonexistent/compose-selection-test.sock"
            command = ["docker", "compose", "--project-directory", directory]
            for profiles, expected in [
                ([], {"worker"}),
                (["--profile", "automatic-updates"], {"worker", "updater"}),
            ]:
                with self.subTest(profiles=profiles):
                    result = subprocess.run(
                        command + profiles + ["config", "--services"],
                        cwd=fixture,
                        env=env,
                        check=True,
                        capture_output=True,
                        text=True,
                        timeout=30,
                    )
                    self.assertEqual(set(result.stdout.split()), expected)


if __name__ == "__main__":
    unittest.main()
