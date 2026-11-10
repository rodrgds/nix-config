#!/usr/bin/env python3
"""Run skill activation without an interactive shell's Node.js PATH."""

import json
from pathlib import Path
import subprocess
import tempfile


repo = Path(__file__).resolve().parents[3]
expression = f"""
let
  cfg = (builtins.getFlake {json.dumps('path:' + str(repo))}).darwinConfigurations.rgo-laptop.config;
in {{
  activation = cfg.home-manager.users.rgo.home.activation.linkSkills.data;
  npmBinDir = cfg.apps.javascript-toolchain.npm.binDir;
  sources = map (spec: spec.source) (import {json.dumps(str(repo) + '/modules/apps/agents/_skill-sources.nix')});
  declared = builtins.concatMap (spec: spec.skills) (import {json.dumps(str(repo) + '/modules/apps/agents/_skill-sources.nix')});
}}
"""
configuration = json.loads(subprocess.check_output(
    ["nix", "eval", "--json", "--impure", "--expr", expression], text=True
))

with tempfile.TemporaryDirectory(prefix="agent-skills-activation-") as directory:
    fixture = Path(directory)
    cli = fixture / "bin" / "skills"
    cli.parent.mkdir()
    # Keep the CLI's real interpreter contract. Node itself must resolve from
    # activation's runtime PATH, and installers must be able to spawn Git.
    cli.write_text("""#!/usr/bin/env node
const fs = require('node:fs');
require('node:child_process').execFileSync('git', ['--version']);
fs.appendFileSync(process.env.INVOCATIONS, JSON.stringify(process.argv.slice(2)) + '\\n');
""")
    cli.chmod(0o755)
    activation = configuration["activation"].replace(
        configuration["npmBinDir"], str(cli.parent)
    )
    script = fixture / "activate"
    script.write_text("set -euo pipefail\n" + activation)
    invocations = fixture / "invocations"
    skills = fixture / ".agents" / "skills"

    def activate():
        invocations.unlink(missing_ok=True)
        subprocess.run(["/bin/bash", str(script)], check=True, env={
            "HOME": str(fixture),
            "PATH": "/usr/bin:/bin",
            "INVOCATIONS": str(invocations),
        })
        if not invocations.exists():
            return [], []
        calls = [json.loads(line) for line in invocations.read_text().splitlines()]
        return (
            [call for call in calls if call and call[0] == "add"],
            [call for call in calls if call and call[0] == "remove"],
        )

    # A fresh home installs every declared source and removes nothing.
    adds, removes = activate()
    assert len(adds) == len(configuration["sources"]), adds
    assert not removes, removes
    assert skills.is_dir()

    # With every declared skill installed, a rebuild makes no network calls.
    # A leftover retired skill is removed without touching declared ones.
    for name in configuration["declared"]:
        (skills / name).mkdir(exist_ok=True)
    (skills / "wizard").mkdir()
    adds, removes = activate()
    assert not adds, adds
    assert len(removes) == 1 and "--global" in removes[0] and "--yes" in removes[0], removes
    assert "wizard" in removes[0] and "code-review" not in removes[0], removes

print("Skill activation installs only what is missing, with a minimal PATH")
