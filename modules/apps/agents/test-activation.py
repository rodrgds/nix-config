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
    subprocess.run(["/bin/bash", str(script)], check=True, env={
        "HOME": str(fixture),
        "PATH": "/usr/bin:/bin",
        "INVOCATIONS": str(invocations),
    })
    calls = [json.loads(line) for line in invocations.read_text().splitlines()]
    assert calls and all(call[0] == "add" for call in calls), calls
    assert (fixture / ".agents" / "skills").is_dir()

print("Skill activation passes with a minimal PATH")
