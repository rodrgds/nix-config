"""Send a bounded, credential-safe Discord notification for a failed backup unit."""
import argparse
import datetime
import json
import math
import os
from pathlib import Path
import re
import socket
import subprocess
import sys
import time
from urllib import error, request


class AlertError(Exception):
    pass


class NoRedirect(request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None


def notify(webhook, content):
    opener = request.build_opener(NoRedirect)
    payload = json.dumps({'content': content, 'allowed_mentions': {'parse': []}}).encode()
    for attempt in range(3):
        message = request.Request(webhook + '?wait=true', data=payload,
                                  headers={'Content-Type': 'application/json',
                                           'User-Agent': 'rgo-nas-backup-alert/1'})
        try:
            with opener.open(message, timeout=10) as response:
                acknowledgement = response.read(8193)
                if response.status != 200 or len(acknowledgement) > 8192:
                    raise AlertError('Discord did not acknowledge delivery')
                try:
                    identifier = json.loads(acknowledgement).get('id')
                except (ValueError, AttributeError):
                    identifier = None
                if not isinstance(identifier, str) or not identifier.isdigit():
                    raise AlertError('Discord did not acknowledge delivery')
                return
        except error.HTTPError as failure:
            with failure:
                if failure.code == 429 and attempt < 2:
                    try:
                        delay = float(json.loads(failure.read(4096))['retry_after'])
                    except (ValueError, KeyError, TypeError):
                        raise AlertError('Discord rate limit did not provide a usable retry delay') from None
                    if not math.isfinite(delay) or not 0 <= delay <= 15:
                        raise AlertError('Discord rate limit exceeds the delivery time budget') from None
                elif 500 <= failure.code <= 599 and attempt < 2:
                    delay = 2 ** attempt
                else:
                    raise AlertError('Discord returned HTTP ' + str(failure.code)) from None
        except (error.URLError, OSError):
            if attempt == 2:
                raise AlertError('Discord transport failed') from None
            delay = 2 ** attempt
        time.sleep(delay)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--systemctl', required=True)
    parser.add_argument('unit')
    args = parser.parse_args(argv)
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9@_.:-]{0,230}\.service', args.unit):
        raise AlertError('Invalid failed-unit name')
    try:
        credential = Path(os.environ['CREDENTIALS_DIRECTORY']) / 'discord-webhook'
        with credential.open('rb') as source:
            webhook = source.read(2049).decode().strip()
    except (KeyError, OSError, UnicodeError):
        raise AlertError('Discord credential is unavailable') from None
    if not re.fullmatch(r'https://discord\.com/api/webhooks/[0-9]+/[A-Za-z0-9_-]{30,200}', webhook):
        raise AlertError('Discord credential has an invalid format')
    try:
        status = subprocess.run([args.systemctl, 'show', args.unit, '--property=Result', '--value'],
                                capture_output=True, text=True, check=True, timeout=5).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        raise AlertError('Could not inspect failed backup unit') from None
    if not re.fullmatch(r'[a-z][a-z-]{0,40}', status):
        status = 'unknown'
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
    notify(webhook, 'NAS backup monitoring on ' + socket.gethostname() + ': ' +
           args.unit + ' failed (result=' + status + ') at ' + stamp +
           '. Inspect the service journal on the host; no backup data is included here.')
    print('Backup failure notification acknowledged by Discord')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except Exception as failure:
        # HTTP/transport exceptions may contain the credential-bearing URL.
        # Only our fixed diagnostic messages may reach the service journal.
        message = str(failure) if isinstance(failure, AlertError) else 'Notification delivery failed'
        print('nas-backup-alert: ' + message, file=sys.stderr)
        sys.exit(1)
