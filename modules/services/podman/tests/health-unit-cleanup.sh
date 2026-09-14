#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cleanup_script="${1:-$repo_root/modules/services/podman/health-unit-cleanup.sh}"
fixture_dir="$(mktemp -d)"
trap 'rm -rf "$fixture_dir"' EXIT
bash_path="$(command -v bash)"

orphan_id=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
live_id=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb

cat > "$fixture_dir/podman" <<EOF
#!$bash_path
if [ "\$1 \$2" = "container list" ]; then
  echo "$live_id"
  exit 0
fi
exit 125
EOF

cat > "$fixture_dir/systemctl" <<EOF
#!$bash_path
case "\$1" in
  list-units)
    pattern="\${!#}"
    case "\$pattern" in
      "$orphan_id-*.timer")
        echo "$orphan_id-deadbeef.timer loaded active waiting"
        ;;
      "$orphan_id-*.service")
        echo "$orphan_id-deadbeef.service loaded failed failed"
        ;;
      "--no-legend")
        cat <<UNITS
$orphan_id-deadbeef.timer loaded active waiting
$orphan_id-deadbeef.service loaded failed failed
$live_id-cafebabe.timer loaded active waiting
$live_id-cafebabe.service loaded inactive dead
ssh.service loaded failed failed
UNITS
        ;;
    esac
    ;;
  stop|reset-failed)
    printf '%s %s\n' "\$1" "\$2" >> "\$HEALTH_CLEANUP_LOG"
    ;;
  *)
    exit 125
    ;;
esac
EOF

chmod +x "$fixture_dir/podman" "$fixture_dir/systemctl"
export HEALTH_CLEANUP_LOG="$fixture_dir/actions"
PATH="$fixture_dir:$PATH" bash "$cleanup_script"

cat > "$fixture_dir/expected" <<EOF
stop $orphan_id-deadbeef.timer
stop $orphan_id-deadbeef.service
reset-failed $orphan_id-deadbeef.service
EOF

diff -u "$fixture_dir/expected" "$HEALTH_CLEANUP_LOG"
