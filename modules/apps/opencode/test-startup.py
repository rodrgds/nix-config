#!/usr/bin/env python3
"""Check that each installed OpenCode entry point starts with the live config.

Run after rebuilding. No model calls or authentication changes are made.
"""

import argparse
import getpass
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys


def check(binary: str, directory: str) -> None:
    config = subprocess.run(
        [binary, "debug", "config"],
        cwd=directory,
        capture_output=True,
        text=True,
        timeout=30,
    )
    if config.returncode:
        # Config output may contain credentials. Report only the diagnostic key.
        keys = re.findall(r"Unrecognized key:\s*(\w+)", config.stderr)
        detail = f"unrecognized keys: {', '.join(keys)}" if keys else "see server logs"
        raise RuntimeError(f"{binary}: config startup failed ({detail})")
    json.loads(config.stdout)

    version = subprocess.check_output([binary, "--version"], text=True).strip()
    if not re.search(r"\bv2\.", version):
        raise RuntimeError(f"{binary}: expected OpenCode v2, got {version}")

    for operation in ("config.get", "provider.list", "agent.list", "mcp.list"):
        response = subprocess.run(
            [
                binary,
                "api",
                operation,
                "--param",
                f"location[directory]={Path(directory).resolve()}",
            ],
            cwd=directory,
            capture_output=True,
            text=True,
            timeout=30,
        )
        if response.returncode:
            raise RuntimeError(f"{binary}: startup request {operation} failed")
        json.loads(response.stdout)
    print(f"PASS {binary}: {version}, config and startup requests")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", action="append", help="Entry point to verify; repeatable")
    parser.add_argument("--directory", default=str(Path.cwd()))
    args = parser.parse_args()
    binaries = args.binary or list(
        dict.fromkeys(
            path
            for path in (
                shutil.which("opencode"),
                f"/etc/profiles/per-user/{getpass.getuser()}/bin/opencode",
            )
            if path and Path(path).exists()
        )
    )
    if not binaries:
        parser.error("no installed OpenCode entry point found")
    try:
        for binary in binaries:
            check(binary, args.directory)
    except (RuntimeError, ValueError, subprocess.SubprocessError) as error:
        print(f"FAIL {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
