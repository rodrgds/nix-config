import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


CONFIGURE = Path(__file__).with_name("configure.sh")
EXECUTOR = {"type": "http", "url": "https://executor.sh/rodrigo-dias/mcp"}
ATTRIBUTION = {"commit": "", "pr": "", "sessionUrl": False}


class ClaudeConfigurationTests(unittest.TestCase):
    def setUp(self):
        self.fixture = tempfile.TemporaryDirectory()
        self.addCleanup(self.fixture.cleanup)
        self.root = Path(self.fixture.name)
        self.home = self.root / "home"
        self.home.mkdir()
        self.skills = self.root / "skills"
        self.skills.mkdir()
        self.managed = self.root / "managed.json"
        self.managed.write_text(json.dumps({"mcpServers": {"executor": EXECUTOR}}))
        self.managed_settings = self.root / "managed-settings.json"
        self.managed_settings.write_text(json.dumps({"attribution": ATTRIBUTION}))
        self.config = self.home / ".claude.json"
        self.settings = self.home / ".claude/settings.json"

    def configure(self, *, check=True):
        return subprocess.run(
            ["bash", "-euo", "pipefail", str(CONFIGURE), str(self.home),
             str(self.skills), str(self.managed), str(self.managed_settings)],
            capture_output=True,
            text=True,
            check=check,
        )

    def test_preserves_account_projects_servers_and_other_settings(self):
        state = {
            "oauthAccount": {"accountUuid": "existing-account"},
            "projects": {"/work": {"hasTrustDialogAccepted": True}},
            "mcpServers": {"personal": {"command": "personal-mcp"}},
        }
        self.config.write_text(json.dumps(state))
        self.settings.parent.mkdir()
        self.settings.write_text(
            '{"theme":"auto","model":"opus","enabledPlugins":{"custom":true}}\n'
        )

        self.configure()

        result = json.loads(self.config.read_text())
        self.assertEqual(result["oauthAccount"], state["oauthAccount"])
        self.assertEqual(result["projects"], state["projects"])
        self.assertEqual(result["mcpServers"]["personal"], {"command": "personal-mcp"})
        self.assertEqual(result["mcpServers"]["executor"], EXECUTOR)
        self.assertEqual(
            json.loads(self.settings.read_text()),
            {
                "theme": "auto",
                "model": "opus",
                "enabledPlugins": {"custom": True},
                "attribution": ATTRIBUTION,
            },
        )
        self.assertEqual(self.config.stat().st_mode & 0o777, 0o600)
        self.assertEqual(self.settings.stat().st_mode & 0o777, 0o600)

    def test_replaces_non_object_attribution(self):
        self.settings.parent.mkdir()
        self.settings.write_text('{"attribution": false}\n')

        self.configure()

        self.assertEqual(json.loads(self.settings.read_text()), {"attribution": ATTRIBUTION})

    def test_shared_skills_stay_live_and_private_skills_survive(self):
        for name in ("shared", "private"):
            source = self.skills / name
            source.mkdir()
            (source / "SKILL.md").write_text("Shared skill\n")
        private = self.home / ".claude/skills/private"
        private.mkdir(parents=True)
        (private / "SKILL.md").write_text("Claude-only customization\n")

        self.configure()

        linked = self.home / ".claude/skills/shared/SKILL.md"
        (self.skills / "shared/SKILL.md").write_text("Updated shared skill\n")
        self.assertEqual(linked.read_text(), "Updated shared skill\n")
        self.assertEqual((private / "SKILL.md").read_text(), "Claude-only customization\n")

    def test_fresh_home_and_repeated_activation(self):
        self.configure()
        self.assertEqual(json.loads(self.config.read_text()), {"mcpServers": {"executor": EXECUTOR}})
        self.assertEqual(json.loads(self.settings.read_text()), {"attribution": ATTRIBUTION})
        config_inode = os.stat(self.config).st_ino
        settings_inode = os.stat(self.settings).st_ino
        self.configure()
        self.assertEqual(os.stat(self.config).st_ino, config_inode)
        self.assertEqual(os.stat(self.settings).st_ino, settings_inode)

    def test_invalid_existing_state_is_preserved(self):
        self.config.write_text("invalid existing state\n")
        self.settings.parent.mkdir()
        self.settings.write_text("invalid existing settings\n")
        result = self.configure(check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.config.read_text(), "invalid existing state\n")
        self.assertEqual(self.settings.read_text(), "invalid existing settings\n")
        self.assertEqual(list(self.home.glob(".claude.json.*")), [])
        self.assertEqual(list(self.home.glob(".claude/settings.json.*")), [])


if __name__ == "__main__":
    unittest.main()
