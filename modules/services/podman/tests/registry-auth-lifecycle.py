#!/usr/bin/env python3
"""Check evaluated runtime dependencies with isolated Linux systemd units.

Pass JSON mapping runtime unit names to their evaluated requires/after lists.
Requires root; creates no containers and never calls a production unit.
"""
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import uuid


def systemctl(*args, check=True):
    return subprocess.run(["systemctl", *args], check=check, text=True,
                          capture_output=True, timeout=30)


def main(config):
    assert sys.platform.startswith("linux") and os.geteuid() == 0
    prefix = "rgo-registry-lifecycle-" + uuid.uuid4().hex
    auth = prefix + "-auth.service"
    directory = Path("/run/systemd/system")
    files = []
    consumers = []
    try:
        auth_path = directory / auth
        auth_path.write_text("[Service]\nType=oneshot\nExecStart=/run/current-system/sw/bin/true\n")
        files.append(auth_path)
        for index, (name, settings) in enumerate(sorted(config.items())):
            unit = prefix + "-consumer-" + str(index) + ".service"
            text = "[Unit]\n"
            if "packages-registry-login.service" in settings["requires"]:
                text += "Requires=" + auth + "\n"
            if "packages-registry-login.service" in settings["after"]:
                text += "After=" + auth + "\n"
            text += ("[Service]\nExecStart=/run/current-system/sw/bin/sleep infinity\n"
                     "Restart=always\nRestartSec=100ms\n")
            path = directory / unit
            path.write_text(text)
            files.append(path)
            consumers.append((name, unit))
        systemctl("daemon-reload")
        systemctl("start", *(unit for _, unit in consumers))
        pids = {unit: systemctl("show", "--value", "-p", "MainPID", unit).stdout.strip()
                for _, unit in consumers}
        assert all(pid.isdigit() and int(pid) > 0 for pid in pids.values())
        for _ in range(3):
            systemctl("restart", auth)
            time.sleep(.25)
            for name, unit in consumers:
                actual = systemctl("show", "--value", "-p", "MainPID", unit).stdout.strip()
                assert actual == pids[unit], (
                    name + ": registry credential refresh interrupted a running consumer")
                assert systemctl("is-active", unit).stdout.strip() == "active"
        print("PASS: registry authentication refresh preserves all " +
              str(len(consumers)) + " evaluated runtime lifetimes")
    finally:
        units = [unit for _, unit in consumers] + [auth]
        systemctl("stop", *units, check=False)
        systemctl("reset-failed", *units, check=False)
        for path in files:
            assert path.parent == directory and path.name.startswith(prefix)
            path.unlink(missing_ok=True)
        systemctl("daemon-reload", check=False)


if __name__ == "__main__":
    main(json.loads(Path(sys.argv[1]).read_text()))
