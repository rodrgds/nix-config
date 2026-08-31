#!/usr/bin/env python3
import hashlib
import hmac
import http.client
import subprocess
import tempfile
import threading
import time
import unittest
from pathlib import Path
from unittest import mock

import deployment_receiver as receiver


class DeploymentReceiverTests(unittest.TestCase):
    def setUp(self):
        self.secret = b"0123456789abcdef" * 2
        self.body = b'{"repository":"getopenpost/openpost","sha":"' + (b"b" * 40) + b'"}'
        self.timestamp = 1_800_000_000
        self.delivery_id = "12345-1"

    def signature(self, method="POST", path="/hooks/deploy-openpost", body=None):
        if body is None:
            body = self.body
        canonical = receiver.canonical_request(
            method,
            path,
            self.timestamp,
            self.delivery_id,
            body,
        )
        return "sha256=" + hmac.new(self.secret, canonical, hashlib.sha256).hexdigest()

    def test_signature_binds_method_path_timestamp_delivery_and_body(self):
        signature = self.signature()

        receiver.verify_signature(
            self.secret,
            "POST",
            "/hooks/deploy-openpost",
            self.timestamp,
            self.delivery_id,
            self.body,
            signature,
        )

        mutations = [
            ("PUT", "/hooks/deploy-openpost", self.body),
            ("POST", "/hooks/deploy-montra", self.body),
            ("POST", "/hooks/deploy-openpost", self.body + b" "),
        ]
        for method, path, body in mutations:
            with self.subTest(method=method, path=path, body=body):
                with self.assertRaises(receiver.RejectedRequest):
                    receiver.verify_signature(
                        self.secret,
                        method,
                        path,
                        self.timestamp,
                        self.delivery_id,
                        body,
                        signature,
                    )

    def test_timestamp_window_and_delivery_id_are_bounded(self):
        receiver.verify_timestamp(self.timestamp, self.timestamp)
        receiver.verify_timestamp(self.timestamp - 300, self.timestamp)
        receiver.verify_timestamp(self.timestamp + 60, self.timestamp)

        for issued_at in (self.timestamp - 301, self.timestamp + 61):
            with self.subTest(issued_at=issued_at):
                with self.assertRaises(receiver.RejectedRequest):
                    receiver.verify_timestamp(issued_at, self.timestamp)

        for delivery_id in ("", "../escape", "contains space", "x" * 129):
            with self.subTest(delivery_id=delivery_id):
                with self.assertRaises(receiver.RejectedRequest):
                    receiver.verify_delivery_id(delivery_id)

    def test_delivery_claim_is_atomic_and_preserves_payload(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            state_root = Path(temporary_directory)
            payload_path = receiver.claim_delivery(
                state_root,
                "openpost",
                self.delivery_id,
                self.body,
            )
            self.assertEqual(payload_path.read_bytes(), self.body)
            self.assertEqual(payload_path.stat().st_mode & 0o777, 0o600)

            with self.assertRaises(receiver.RejectedRequest):
                receiver.claim_delivery(
                    state_root,
                    "openpost",
                    self.delivery_id,
                    self.body,
                )

    def test_placeholder_and_short_secrets_are_rejected(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            secret_path = Path(temporary_directory) / "secret"
            for secret in (b"short", b"changeme" * 8, b"x" * 64):
                with self.subTest(secret=secret[:8]):
                    secret_path.write_bytes(secret)
                    with self.assertRaises(receiver.ConfigurationError):
                        receiver.load_secret(secret_path)

            secret_path.write_bytes(self.secret)
            self.assertEqual(receiver.load_secret(secret_path), self.secret)

    def test_http_contract_accepts_once_and_returns_fixed_responses(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            temporary_root = Path(temporary_directory)
            secret_path = temporary_root / "secret"
            secret_path.write_bytes(self.secret)
            route = receiver.Route(
                name="openpost",
                path="/hooks/deploy-openpost",
                secret_file=secret_path,
                handler=temporary_root / "handler",
            )

            class RecordingServer(receiver.DeploymentServer):
                dispatched: list[tuple[str, str, bytes]] = []

                def dispatch(self, route, delivery_id, payload_path):
                    self.dispatched.append(
                        (route.name, delivery_id, payload_path.read_bytes())
                    )

            server = RecordingServer(
                ("127.0.0.1", 0),
                temporary_root / "state",
                Path("/bin/false"),
                {route.path: route},
            )
            server_thread = threading.Thread(target=server.serve_forever, daemon=True)
            server_thread.start()
            try:
                timestamp = int(time.time())
                self.timestamp = timestamp
                headers = {
                    "Content-Type": "application/json",
                    "X-Deploy-Timestamp": str(timestamp),
                    "X-Deploy-Delivery": self.delivery_id,
                    "X-Deploy-Signature-256": self.signature(),
                }

                status, body = self.request(server, "POST", route.path, headers, self.body)
                self.assertEqual((status, body), (200, receiver.ACCEPTED_RESPONSE))
                self.assertEqual(
                    server.dispatched,
                    [(route.name, self.delivery_id, self.body)],
                )

                status, body = self.request(server, "POST", route.path, headers, self.body)
                self.assertEqual((status, body), (401, receiver.REJECTED_RESPONSE))

                tampered_headers = dict(headers)
                tampered_headers["X-Deploy-Delivery"] = "different-delivery"
                status, body = self.request(
                    server,
                    "POST",
                    route.path,
                    tampered_headers,
                    self.body,
                )
                self.assertEqual((status, body), (401, receiver.REJECTED_RESPONSE))

                status, body = self.request(server, "GET", "/healthz", {}, b"")
                self.assertEqual((status, body), (200, b'{"status":"ok"}\n'))
            finally:
                server.shutdown()
                server.server_close()
                server_thread.join(timeout=2)

    def test_dispatch_failure_retains_replay_claim(self):
        for dispatch_error in (
            subprocess.TimeoutExpired("systemd-run", 3660),
            subprocess.CalledProcessError(1, "systemd-run"),
        ):
            with self.subTest(error=type(dispatch_error).__name__):
                self.assert_dispatch_failure_consumes_delivery(dispatch_error)

    def assert_dispatch_failure_consumes_delivery(self, dispatch_error):
        with tempfile.TemporaryDirectory() as temporary_directory:
            temporary_root = Path(temporary_directory)
            secret_path = temporary_root / "secret"
            secret_path.write_bytes(self.secret)
            route = receiver.Route(
                name="openpost",
                path="/hooks/deploy-openpost",
                secret_file=secret_path,
                handler=temporary_root / "handler",
            )

            class FailingServer(receiver.DeploymentServer):
                def dispatch(self, route, delivery_id, payload_path):
                    raise dispatch_error

            server = FailingServer(
                ("127.0.0.1", 0),
                temporary_root / "state",
                Path("/bin/false"),
                {route.path: route},
            )
            server_thread = threading.Thread(target=server.serve_forever, daemon=True)
            server_thread.start()
            try:
                self.timestamp = int(time.time())
                headers = {
                    "Content-Type": "application/json",
                    "X-Deploy-Timestamp": str(self.timestamp),
                    "X-Deploy-Delivery": self.delivery_id,
                    "X-Deploy-Signature-256": self.signature(),
                }
                status, body = self.request(server, "POST", route.path, headers, self.body)
                self.assertEqual((status, body), (503, receiver.FAILED_RESPONSE))
                status, body = self.request(server, "POST", route.path, headers, self.body)
                self.assertEqual((status, body), (401, receiver.REJECTED_RESPONSE))
            finally:
                server.shutdown()
                server.server_close()
                server_thread.join(timeout=2)

    def test_dispatch_expands_failure_unit_name(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            temporary_root = Path(temporary_directory)
            payload_path = temporary_root / "payload.json"
            payload_path.write_bytes(self.body)
            route = receiver.Route(
                name="personal-website",
                path="/hooks/deploy-personal-website",
                secret_file=temporary_root / "secret",
                handler=temporary_root / "handler",
            )
            server = object.__new__(receiver.DeploymentServer)
            server.systemd_run = Path("/run/systemd-run")

            with mock.patch.object(receiver.subprocess, "run") as run:
                server.dispatch(route, self.delivery_id, payload_path)

            command = run.call_args.args[0]
            unit_name = f"deploy-{route.name}-{self.delivery_id}"
            self.assertIn(f"--unit={unit_name}", command)
            self.assertIn(
                f"--property=OnFailure=openpost-ops-alert@{unit_name}.service",
                command,
            )
            self.assertNotIn(
                "--property=OnFailure=openpost-ops-alert@%n.service",
                command,
            )

    @staticmethod
    def request(server, method, path, headers, body):
        connection = http.client.HTTPConnection(*server.server_address, timeout=2)
        try:
            connection.request(method, path, body=body, headers=headers)
            response = connection.getresponse()
            return response.status, response.read()
        finally:
            connection.close()


if __name__ == "__main__":
    unittest.main()
