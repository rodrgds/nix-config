#!/usr/bin/env python3
"""Check that the evaluated OCI readiness boundary waits for Directus health.

Run as root on Linux with a cached exact image: startup-readiness.py CONFIG.json.
Uses synthetic credentials, private temporary data and no network or host port.
"""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import uuid


def run(*args, check=True):
    return subprocess.run(args, text=True, capture_output=True, check=check)


def main():
    config = json.loads(Path(sys.argv[1]).read_text())
    image = config['image']
    assert '@sha256:' in image
    run('podman', 'image', 'exists', image)
    name = 'directus-startup-fixture-' + uuid.uuid4().hex[:12]
    unit = name + '.service'
    identifier = None
    with tempfile.TemporaryDirectory(prefix=name) as temporary:
        directory = Path(temporary)
        directory.chmod(0o700)
        os.chown(directory, 1000, 1000)
        command = ['podman', 'run', '--pull=never', '--rm', '--name', name,
                   '--sdnotify=' + config['podman']['sdnotify'], '--network=none',
                   '--memory=512m', '--memory-swap=512m', '--cpus=1',
                   '--pids-limit=128', '--cap-drop=ALL',
                   '--security-opt=no-new-privileges', '--user=1000:1000',
                   '--volume', f'{directory}:/directus/database']
        command += [x for x in config['extraOptions'] if x.startswith('--health-')]
        for target in ['uploads', 'extensions']:
            command += ['--tmpfs', f'/directus/{target}:rw,size=16m,mode=1777']
        env = {k: v for k, v in config['environment'].items() if k.startswith('DB_')}
        env.update(KEY='synthetic-key', SECRET='synthetic-secret',
                   ADMIN_EMAIL='fixture@example.com',
                   ADMIN_PASSWORD='synthetic-only-password', TELEMETRY='false')
        for key, value in env.items():
            command += ['--env', f'{key}={value}']
        try:
            run('systemd-run', '--quiet', '--no-block', '--collect', '--unit=' + unit,
                '--property=Type=notify', '--property=NotifyAccess=all',
                '--property=TimeoutStartSec=180', '--property=TimeoutStopSec=15',
                '--property=LimitCORE=0', *command, image)
            deadline = time.monotonic() + 170
            saw_starting = False
            while time.monotonic() < deadline:
                result = run('podman', 'inspect', name, check=False)
                if result.returncode:
                    time.sleep(0.25)
                    continue
                container = json.loads(result.stdout)[0]
                identifier = container['Id']
                health = container['State']['Health']['Status']
                state = run('systemctl', 'show', unit, '-p', 'ActiveState', '--value').stdout.strip()
                if health == 'starting':
                    saw_starting = True
                    assert state == 'activating', f'unit became {state} before startup/DB health passed'
                elif health == 'healthy' and state == 'active':
                    assert saw_starting, 'startup boundary was not observed'
                    failed = run('systemctl', 'list-units', '--failed', '--plain', '--no-legend', identifier + '-*.service').stdout.strip()
                    assert not failed, 'failed startup transient unit survived readiness'
                    print('PASS: notify unit remained activating through startup; active only after health; no failed startup units')
                    return
                time.sleep(0.25)
            raise AssertionError('readiness did not complete within bounded fixture window')
        finally:
            run('systemctl', 'stop', unit, check=False)
            run('podman', 'rm', '--force', name, check=False)
            if identifier:
                units = run('systemctl', 'list-units', '--all', '--plain', '--no-legend', identifier + '-*.timer', identifier + '-*.service').stdout.splitlines()
                for line in units:
                    candidate = line.split()[0]
                    if candidate.startswith(identifier + '-'):
                        run('systemctl', 'stop', candidate, check=False)
                        run('systemctl', 'reset-failed', candidate, check=False)


if __name__ == '__main__':
    main()
