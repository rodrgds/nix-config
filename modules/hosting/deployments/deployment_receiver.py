#!/usr/bin/env python3
"""Authenticated deployment receiver with replay-safe, fixed responses."""

from __future__ import annotations

import argparse
import hashlib
import hmac
import json
import os
import re
import shutil
import subprocess
import sys
import threading
import time
from dataclasses import dataclass
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit


MAX_BODY_BYTES = 1024 * 1024
MAX_PAST_SECONDS = 300
MAX_FUTURE_SECONDS = 60
REPLAY_RETENTION_SECONDS = 7 * 24 * 60 * 60
DELIVERY_ID_PATTERN = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$")
ROUTE_NAME_PATTERN = re.compile(r"^[a-z][a-z0-9-]{0,31}$")
SIGNATURE_PATTERN = re.compile(r"^sha256=([0-9a-f]{64})$")
PLACEHOLDER_MARKERS = (b"changeme", b"change-me", b"replace-me", b"placeholder")
ACCEPTED_RESPONSE = b'{"status":"completed"}\n'
REJECTED_RESPONSE = b'{"status":"rejected"}\n'
FAILED_RESPONSE = b'{"status":"failed"}\n'


class RejectedRequest(Exception):
    """The request failed authentication or replay validation."""


class ConfigurationError(Exception):
    """The receiver configuration cannot be used safely."""


@dataclass(frozen=True)
class Route:
    name: str
    path: str
    secret_file: Path
    handler: Path


def canonical_request(
    method: str,
    path: str,
    timestamp: int,
    delivery_id: str,
    body: bytes,
) -> bytes:
    body_digest = hashlib.sha256(body).hexdigest()
    return (
        f"{method}\n{path}\n{timestamp}\n{delivery_id}\n{body_digest}"
    ).encode("ascii")


def verify_signature(
    secret: bytes,
    method: str,
    path: str,
    timestamp: int,
    delivery_id: str,
    body: bytes,
    supplied_signature: str,
) -> None:
    signature_match = SIGNATURE_PATTERN.fullmatch(supplied_signature)
    if signature_match is None:
        raise RejectedRequest("invalid signature encoding")
    expected_signature = hmac.new(
        secret,
        canonical_request(method, path, timestamp, delivery_id, body),
        hashlib.sha256,
    ).hexdigest()
    if not hmac.compare_digest(expected_signature, signature_match.group(1)):
        raise RejectedRequest("signature mismatch")


def verify_timestamp(issued_at: int, now: int) -> None:
    if issued_at < now - MAX_PAST_SECONDS:
        raise RejectedRequest("request is too old")
    if issued_at > now + MAX_FUTURE_SECONDS:
        raise RejectedRequest("request is too far in the future")


def verify_delivery_id(delivery_id: str) -> None:
    if DELIVERY_ID_PATTERN.fullmatch(delivery_id) is None:
        raise RejectedRequest("invalid delivery ID")


def load_secret(secret_path: Path) -> bytes:
    try:
        secret = secret_path.read_bytes().strip()
    except OSError as error:
        raise ConfigurationError(f"cannot read secret file {secret_path}") from error
    lowered_secret = secret.lower()
    if len(secret) < 32:
        raise ConfigurationError(f"secret file {secret_path} is shorter than 32 bytes")
    if any(marker in lowered_secret for marker in PLACEHOLDER_MARKERS):
        raise ConfigurationError(f"secret file {secret_path} contains a placeholder")
    if len(set(secret)) == 1:
        raise ConfigurationError(f"secret file {secret_path} has no entropy")
    return secret


def claim_delivery(
    state_root: Path,
    route_name: str,
    delivery_id: str,
    body: bytes,
) -> Path:
    route_root = state_root / route_name
    route_root.mkdir(mode=0o700, parents=True, exist_ok=True)
    delivery_root = route_root / delivery_id
    try:
        delivery_root.mkdir(mode=0o700)
    except FileExistsError as error:
        raise RejectedRequest("delivery ID was already used") from error

    payload_path = delivery_root / "payload.json"
    try:
        file_descriptor = os.open(
            payload_path,
            os.O_WRONLY | os.O_CREAT | os.O_EXCL,
            0o600,
        )
        with os.fdopen(file_descriptor, "wb") as payload_file:
            payload_file.write(body)
            payload_file.flush()
            os.fsync(payload_file.fileno())
    except Exception:
        shutil.rmtree(delivery_root, ignore_errors=True)
        raise
    return payload_path


def release_delivery(payload_path: Path) -> None:
    shutil.rmtree(payload_path.parent, ignore_errors=True)


def prune_deliveries(state_root: Path, now: int) -> None:
    cutoff = now - REPLAY_RETENTION_SECONDS
    if not state_root.exists():
        return
    for route_root in state_root.iterdir():
        if not route_root.is_dir():
            continue
        for delivery_root in route_root.iterdir():
            try:
                if delivery_root.is_dir() and delivery_root.stat().st_mtime < cutoff:
                    shutil.rmtree(delivery_root)
            except FileNotFoundError:
                continue


def load_routes(config_path: Path) -> tuple[str, int, Path, Path, dict[str, Route]]:
    try:
        raw_config = json.loads(config_path.read_text())
        listen_address = raw_config["listen_address"]
        listen_port = raw_config["listen_port"]
        state_directory = Path(raw_config["state_directory"])
        systemd_run = Path(raw_config["systemd_run"])
        raw_routes = raw_config["routes"]
    except (OSError, KeyError, TypeError, ValueError, json.JSONDecodeError) as error:
        raise ConfigurationError("invalid receiver configuration") from error

    if not isinstance(listen_address, str) or listen_address not in ("127.0.0.1", "::1"):
        raise ConfigurationError("receiver must listen on a loopback address")
    if not isinstance(listen_port, int) or not 1 <= listen_port <= 65535:
        raise ConfigurationError("invalid listen port")
    if not state_directory.is_absolute() or not systemd_run.is_absolute():
        raise ConfigurationError("state_directory and systemd_run must be absolute")
    if not isinstance(raw_routes, list) or not raw_routes:
        raise ConfigurationError("at least one route is required")

    routes: dict[str, Route] = {}
    route_names: set[str] = set()
    for raw_route in raw_routes:
        try:
            route = Route(
                name=raw_route["name"],
                path=raw_route["path"],
                secret_file=Path(raw_route["secret_file"]),
                handler=Path(raw_route["handler"]),
            )
        except (KeyError, TypeError) as error:
            raise ConfigurationError("invalid route configuration") from error
        if ROUTE_NAME_PATTERN.fullmatch(route.name) is None:
            raise ConfigurationError(f"invalid route name {route.name!r}")
        if route.name in route_names:
            raise ConfigurationError(f"duplicate route name {route.name!r}")
        if not route.path.startswith("/hooks/") or urlsplit(route.path).path != route.path:
            raise ConfigurationError(f"invalid route path {route.path!r}")
        if route.path in routes:
            raise ConfigurationError(f"duplicate route path {route.path!r}")
        if not route.secret_file.is_absolute() or not route.handler.is_absolute():
            raise ConfigurationError("route files must use absolute paths")
        load_secret(route.secret_file)
        if not route.handler.is_file():
            raise ConfigurationError(f"handler does not exist: {route.handler}")
        routes[route.path] = route
        route_names.add(route.name)

    return listen_address, listen_port, state_directory, systemd_run, routes


class DeploymentServer(ThreadingHTTPServer):
    daemon_threads = True
    request_queue_size = 16

    def __init__(
        self,
        server_address: tuple[str, int],
        state_directory: Path,
        systemd_run: Path,
        routes: dict[str, Route],
    ) -> None:
        super().__init__(server_address, DeploymentRequestHandler)
        self.state_directory = state_directory
        self.systemd_run = systemd_run
        self.routes = routes
        self.request_slots = threading.BoundedSemaphore(8)

    def get_request(self):
        request, client_address = super().get_request()
        request.settimeout(30)
        return request, client_address

    def process_request(self, request, client_address):
        if not self.request_slots.acquire(blocking=False):
            self.shutdown_request(request)
            return
        super().process_request(request, client_address)

    def process_request_thread(self, request, client_address):
        try:
            super().process_request_thread(request, client_address)
        finally:
            self.request_slots.release()

    def dispatch(self, route: Route, delivery_id: str, payload_path: Path) -> None:
        unit_name = f"deploy-{route.name}-{delivery_id}"
        subprocess.run(
            [
                str(self.systemd_run),
                "--quiet",
                "--wait",
                "--collect",
                "--service-type=oneshot",
                f"--unit={unit_name}",
                "--property=TimeoutStartSec=60min",
                "--property=OnFailure=openpost-ops-alert@%n.service",
                str(route.handler),
                str(payload_path),
            ],
            check=True,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=3660,
        )


class DeploymentRequestHandler(BaseHTTPRequestHandler):
    server: DeploymentServer
    server_version = ""
    sys_version = ""

    def do_GET(self) -> None:
        if urlsplit(self.path).path == "/healthz":
            self.respond(200, b'{"status":"ok"}\n')
            return
        self.respond(405, REJECTED_RESPONSE)

    def do_POST(self) -> None:
        request_path = urlsplit(self.path).path
        route = self.server.routes.get(request_path)
        payload_path: Path | None = None
        try:
            if route is None or self.path != request_path:
                raise RejectedRequest("unknown route")
            body = self.read_body()
            issued_at = self.read_timestamp_header()
            delivery_id = self.headers.get("X-Deploy-Delivery", "")
            supplied_signature = self.headers.get("X-Deploy-Signature-256", "")
            verify_delivery_id(delivery_id)
            verify_timestamp(issued_at, int(time.time()))
            verify_signature(
                load_secret(route.secret_file),
                self.command,
                request_path,
                issued_at,
                delivery_id,
                body,
                supplied_signature,
            )
            prune_deliveries(self.server.state_directory, int(time.time()))
            payload_path = claim_delivery(
                self.server.state_directory,
                route.name,
                delivery_id,
                body,
            )
            self.server.dispatch(route, delivery_id, payload_path)
        except RejectedRequest:
            self.respond(401, REJECTED_RESPONSE)
            return
        except subprocess.TimeoutExpired:
            # The transient unit may still be running after the client-side
            # wait expires. Retain the claim so the same delivery cannot start
            # a second concurrent deployment.
            self.respond(503, FAILED_RESPONSE)
            return
        except (ConfigurationError, OSError, subprocess.SubprocessError):
            if payload_path is not None:
                release_delivery(payload_path)
            self.respond(503, FAILED_RESPONSE)
            return
        self.respond(200, ACCEPTED_RESPONSE)

    def read_body(self) -> bytes:
        content_length_header = self.headers.get("Content-Length")
        if content_length_header is None or not content_length_header.isdigit():
            raise RejectedRequest("missing content length")
        content_length = int(content_length_header)
        if content_length > MAX_BODY_BYTES:
            raise RejectedRequest("request body is too large")
        body = self.rfile.read(content_length)
        if len(body) != content_length:
            raise RejectedRequest("truncated request body")
        return body

    def read_timestamp_header(self) -> int:
        timestamp_header = self.headers.get("X-Deploy-Timestamp", "")
        if not timestamp_header.isdigit() or len(timestamp_header) > 10:
            raise RejectedRequest("invalid timestamp")
        return int(timestamp_header)

    def respond(self, status_code: int, body: bytes) -> None:
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("Connection", "close")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, message_format: str, *args: object) -> None:
        print(
            json.dumps(
                {
                    "event": "deployment_receiver_request",
                    "client": self.client_address[0],
                    "method": self.command,
                    "path": urlsplit(self.path).path,
                    "message": message_format % args,
                },
                separators=(",", ":"),
            ),
            file=sys.stderr,
            flush=True,
        )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("config", type=Path)
    arguments = parser.parse_args()
    try:
        listen_address, listen_port, state_directory, systemd_run, routes = load_routes(
            arguments.config
        )
        state_directory.mkdir(mode=0o700, parents=True, exist_ok=True)
        server = DeploymentServer(
            (listen_address, listen_port),
            state_directory,
            systemd_run,
            routes,
        )
        server.serve_forever()
    except (ConfigurationError, OSError) as error:
        print(f"deployment receiver failed to start: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
