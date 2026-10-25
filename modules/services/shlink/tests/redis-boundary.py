#!/usr/bin/env python3
"""Verify the evaluated Redis command offers a Unix socket and no TCP listener.

Pass JSON containing the Redis container's evaluated `cmd` list. Requires
redis-server on PATH. Runs only in a temporary local directory.
"""

import json
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import time


def main():
    command = json.loads(Path(sys.argv[1]).read_text())
    with tempfile.TemporaryDirectory(prefix="redis-boundary-") as temporary:
        endpoint = str(Path(temporary) / "redis.sock")
        # Keep the pre-fix negative control away from any real Redis instance.
        with socket.socket() as probe:
            probe.bind(("127.0.0.1", 0))
            port = probe.getsockname()[1]
        if "--port" not in command:
            command += ["--bind", "127.0.0.1", "--port", str(port)]
        command = [endpoint if arg == "/run/shlink-redis/redis.sock" else arg for arg in command]
        process = subprocess.Popen(
            command + ["--dir", temporary],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        try:
            for _ in range(100):
                if Path(endpoint).exists():
                    break
                if process.poll() is not None:
                    raise AssertionError("Redis failed to start")
                time.sleep(0.02)
            else:
                raise AssertionError("Redis did not offer the private Unix socket")
            with socket.socket(socket.AF_UNIX) as client:
                client.settimeout(3)
                client.connect(endpoint)
                client.sendall(b"*1\r\n$4\r\nPING\r\n")
                assert client.recv(256) == b"+PONG\r\n", "Shlink socket transport failed"
            # Redis reports its effective TCP port without accessing stored data.
            with socket.socket(socket.AF_UNIX) as client:
                client.settimeout(3)
                client.connect(endpoint)
                client.sendall(b"*2\r\n$4\r\nINFO\r\n$6\r\nserver\r\n")
                response = client.recv(65536)
                assert b"tcp_port:0\r\n" in response, "Redis still offers TCP"
            print("PASS: private Unix socket responds to PING; effective TCP port is zero")
        finally:
            process.terminate()
            process.wait(timeout=10)


if __name__ == "__main__":
    main()
