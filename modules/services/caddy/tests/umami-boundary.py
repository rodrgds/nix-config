#!/usr/bin/env python3
"""Exercise evaluated Umami and Directus Caddy routes against a local upstream.

Pass evaluated extraConfig as `caddy` and optionally `directus`.
Requires caddy on PATH. Does not contact production or submit analytics events.
"""

import http.client
import http.server
import json
import os
from pathlib import Path
import re
import socket
import subprocess
import sys
import tempfile
import threading
import time
import urllib.error
import urllib.request


class Upstream(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/websocket-hop-headers":
            self.send_response_only(101)
            self.send_header("Connection", "Upgrade, X-Upstream-Hop")
            self.send_header("Upgrade", "websocket")
            self.send_header("Alt-Svc", 'h2="untrusted.invalid:443"')
            self.send_header("Keep-Alive", "timeout=999")
            self.send_header("Proxy-Authenticate", 'Basic realm="untrusted"')
            self.send_header("X-Upstream-Hop", "must-not-cross-proxy")
            self.send_header("X-End-To-End", "preserved")
            self.end_headers()
            self.close_connection = True
            return
        body = json.dumps({key.lower(): value for key, value in self.headers.items()}).encode()
        self.send_response(200)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *_args):
        pass


def check_proxy(config, check):
    upstream = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Upstream)
    threading.Thread(target=upstream.serve_forever, daemon=True).start()
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        port = sock.getsockname()[1]
    config = re.sub(r"localhost:[0-9]+", f"127.0.0.1:{upstream.server_port}", config)
    with tempfile.TemporaryDirectory(prefix="umami-caddy-test-") as temporary:
        path = Path(temporary) / "Caddyfile"
        path.write_text("{\n admin off\n auto_https off\n}\n" + f"http://127.0.0.1:{port} {{\n{config}\n}}\n")
        environment = dict(os.environ, XDG_DATA_HOME=temporary, XDG_CONFIG_HOME=temporary)
        process = subprocess.Popen(
            ["caddy", "run", "--config", str(path), "--adapter", "caddyfile"],
            env=environment,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        try:
            url = f"http://127.0.0.1:{port}/api/me"
            for _ in range(100):
                try:
                    urllib.request.urlopen(url, timeout=0.5).close()
                    break
                except (urllib.error.URLError, TimeoutError):
                    if process.poll() is not None:
                        raise AssertionError("Caddy did not accept the evaluated route")
                    time.sleep(0.05)
            else:
                raise AssertionError("Caddy did not start")

            check(f"http://127.0.0.1:{port}")
        finally:
            process.terminate()
            process.wait(timeout=10)
            upstream.shutdown()
            upstream.server_close()


def check_umami(base):
    request = urllib.request.Request(base + "/api/me", headers={
        "X-Umami-Share-Token": "fixture-cache-token",
        "X-Umami-Share-Context": "1",
        "Authorization": "Bearer fixture-login-token",
    })
    with urllib.request.urlopen(request, timeout=5) as response:
        headers = json.load(response)
    assert "x-umami-share-token" not in headers, "untrusted share token reached Umami"
    assert "x-umami-share-context" not in headers, "untrusted share context reached Umami"
    assert headers.get("authorization") == "Bearer fixture-login-token", "normal login was removed"
    # The public tracking script must remain reachable through the same route.
    with urllib.request.urlopen(base + "/script.js", timeout=5) as response:
        assert response.status == 200
    print("PASS: forged share headers removed; normal auth and tracking script preserved")
    check_upgrade_headers(base)


def check_upgrade_headers(base):
    # GHSA-8qx7-j2v2-x6q5: a real 101 response must strip hop-by-hop headers
    # while preserving the WebSocket upgrade and ordinary end-to-end headers.
    from urllib.parse import urlsplit
    target = urlsplit(base)
    client = http.client.HTTPConnection(target.hostname, target.port, timeout=5)
    try:
        client.request("GET", "/websocket-hop-headers", headers={
            "Connection": "Upgrade", "Upgrade": "websocket",
        })
        response = client.getresponse()
        assert response.status == 101, "WebSocket upgrade was blocked"
        headers = {key.lower(): value for key, value in response.getheaders()}
        for name in ("alt-svc", "keep-alive", "proxy-authenticate", "x-upstream-hop"):
            assert name not in headers, f"upgrade leaked hop-by-hop header: {name}"
        assert headers.get("upgrade", "").lower() == "websocket"
        assert headers.get("connection", "").lower() == "upgrade"
        assert headers.get("x-end-to-end") == "preserved"
    finally:
        client.close()
    print("PASS: WebSocket upgrade strips hop-by-hop headers and preserves protocol headers")


def check_directus(base):
    from urllib.parse import urlsplit
    target = urlsplit(base)
    # Linux routes the whole 127/8 range locally. Only 127.0.0.1 is trusted by
    # the production rule; 127.0.0.2 supplies a real untrusted transport peer.
    for forwarded in (None, "100.64.0.1", "127.0.0.1"):
        client = http.client.HTTPConnection(target.hostname, target.port,
            source_address=("127.0.0.2", 0), timeout=5)
        try:
            headers = {} if forwarded is None else {"X-Forwarded-For": forwarded}
            client.request("GET", "/server/health", headers=headers)
            response = client.getresponse()
            assert response.status == 403, "untrusted peer reached Directus"
            response.read()
        finally:
            client.close()
    with urllib.request.urlopen(base + "/server/health", timeout=5) as response:
        assert response.status == 200, "trusted local administration was blocked"
    print("PASS: Directus rejects untrusted peers and spoofed forwarding headers")


def main():
    configs = json.loads(Path(sys.argv[1]).read_text())
    check_proxy(configs["caddy"], check_umami)
    if "directus" in configs:
        check_proxy(configs["directus"], check_directus)


if __name__ == "__main__":
    main()
