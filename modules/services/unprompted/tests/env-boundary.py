#!/usr/bin/env python3
"""Guard credential grants at the evaluated OCI/systemd boundary, using dummy values.

Usage: nix eval --impure --json --file evaluate.expr | python3 env-boundary.py
No runtime secret files, application data, or production endpoints are read.
"""

import json
import subprocess
import sys


def environments(config):
    # Unique markers expose accidental grants even when templates are reorganized.
    markers = {
        name: "dummy-" + name + "-0123456789abcdef0123456789abcdef"
        for name, placeholder in config["placeholders"].items()
        if any(placeholder in template["content"] for template in config["templates"].values())
    }
    markers["unprompted_postgres_password"] += "-'\\:$#="
    if "unprompted_postgres_admin_password" in markers:
        markers["unprompted_postgres_admin_password"] += "-'\\:$#="
    files = {}
    for template in config["templates"].values():
        content = template["content"]
        for name, marker in markers.items():
            content = content.replace(config["placeholders"][name], marker)
        files[template["path"]] = dict(
            line.split("=", 1)
            for line in content.splitlines()
            if line.strip() and not line.startswith("#")
        )

    def resolve(paths, inline=None):
        env = {}
        for path in ([paths] if isinstance(paths, str) else paths):
            env.update(files[path])
        env.update(inline or {})
        # Observe a child process's effective environment, without inherited secrets.
        result = subprocess.run(
            [sys.executable, "-I", "-c", "import os,json; print(json.dumps(dict(os.environ)))"],
            env=env, capture_output=True, text=True, check=True,
        )
        return json.loads(result.stdout)

    envs = {
        name.removeprefix("unprompted-"): resolve(container["environmentFiles"], container["environment"])
        for name, container in config["containers"].items()
    }
    envs["migrate"] = resolve(config["initialize"])
    envs["deploy-migrate"] = resolve(config["deployInitialize"])
    return envs, markers


def check(config):
    envs, markers = environments(config)
    # Independent privilege policy: web has no credentials; only PG gets admin;
    # worker cannot sign auth sessions. API still owns all six credential categories.
    grants = {
        "web": set(),
        "postgres": {"unprompted_postgres_password", "unprompted_postgres_admin_password"},
        "migrate": {"unprompted_postgres_password"},
        "deploy-migrate": {"unprompted_postgres_password"},
        "worker": set(markers) - {"unprompted_better_auth_secret", "unprompted_postgres_admin_password"},
        "api": set(markers) - {"unprompted_postgres_admin_password"},
    }
    for consumer, allowed in grants.items():
        values = "\n".join(envs[consumer].values())
        actual = {name for name, marker in markers.items() if marker in values}
        assert actual == allowed, (
            f"{consumer}: credential grants differ, unexpected={sorted(actual - allowed)}, "
            f"missing={sorted(allowed - actual)}"
        )
    for name, template in config["templates"].items():
        assert template["mode"] == "0400", f"{name}: secret template is not root-only"
    assert envs["postgres"]["APP_POSTGRES_PASSWORD"] == envs["migrate"]["POSTGRES_PASSWORD"]
    assert envs["postgres"]["POSTGRES_PASSWORD"] != envs["migrate"]["POSTGRES_PASSWORD"]
    assert envs["migrate"] == envs["deploy-migrate"], "boot and deploy migration scopes differ"
    print("PASS: evaluated web, PostgreSQL, boot/deploy migration, API and worker credential boundaries")


if __name__ == "__main__":
    check(json.load(sys.stdin))
