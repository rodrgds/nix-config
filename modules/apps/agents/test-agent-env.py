#!/usr/bin/env python3
"""Exercise agent startup against real, isolated direnv projects."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


HOOK = Path(__file__).with_name("agent-env.sh")


class AgentEnvironmentTest(unittest.TestCase):
    shell = "/bin/bash"

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="agent-env-test-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.env = {
            "HOME": str(self.root),
            "PATH": os.environ["PATH"],
            "XDG_CONFIG_HOME": str(self.root / "config"),
            "XDG_DATA_HOME": str(self.root / "data"),
            "XDG_CACHE_HOME": str(self.root / "cache"),
        }
        self.direnv = shutil.which("direnv")
        self.project = self.root / "project"
        self.project.mkdir()
        tools = self.project / "tools"
        tools.mkdir()
        command = tools / "project-tool"
        command.write_text("#!/bin/sh\nprintf 'project-ready\\n'\n")
        command.chmod(0o755)
        (self.project / ".envrc").write_text('PATH_add "$PWD/tools"\n')
        subprocess.run([self.direnv, "allow"], cwd=self.project,
                       env=self.env, check=True, capture_output=True)

    def run_shell(self, script):
        return subprocess.run(
            [self.shell, "-c", 'export PATH="$2"\n' + script,
             "agent-env-test", str(HOOK), self.env["PATH"]],
            cwd=self.project, env=self.env, capture_output=True, text=True,
            timeout=20,
        )

    def test_inherited_loaded_flags_do_not_hide_a_reset_path(self):
        result = self.run_shell('''
            original_path="$PATH"
            eval "$(direnv export bash)"
            export AGENT_ENV_LOADED=1
            export PATH="$original_path"
            . "$1"
            project-tool
        ''')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "project-ready")

    def test_fresh_shell_loads_project_tools(self):
        result = self.run_shell('. "$1"; project-tool')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "project-ready")

    def test_revoked_project_is_not_loaded_from_an_agent_cache(self):
        result = self.run_shell('''
            original_path="$PATH"
            . "$1"
            direnv deny
            export PATH="$original_path"
            unset AGENT_ENV_LOADED
            . "$1"
            ! command -v project-tool
        ''')
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_switching_projects_removes_the_previous_project_tools(self):
        other = self.root / "other"
        other.mkdir()
        (other / ".envrc").write_text("export OTHER_PROJECT=ready\n")
        subprocess.run([self.direnv, "allow"], cwd=other,
                       env=self.env, check=True, capture_output=True)
        result = self.run_shell('''
            . "$1"
            cd ../other
            . "$1"
            test "$OTHER_PROJECT" = ready && ! command -v project-tool
        ''')
        self.assertEqual(result.returncode, 0, result.stderr)


@unittest.skipUnless(shutil.which("zsh"), "Zsh is not installed")
class AgentEnvironmentZshTest(AgentEnvironmentTest):
    shell = shutil.which("zsh")


if __name__ == "__main__":
    unittest.main()
