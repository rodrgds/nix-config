#!/usr/bin/env bash
set -euo pipefail

# Exercise the real profile loader and HTTP server with isolated session state.
launcher="${1:-dsh}"
test_dir=$(mktemp -d)
server_pid=
cleanup() {
  if [[ -n "$server_pid" ]]; then
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true
  fi
  rm -rf "$test_dir"
}
trap cleanup EXIT

DSH_HOME="$test_dir/home" "$launcher" web --no-open --port 0 >"$test_dir/server.log" 2>&1 &
server_pid=$!
for ((attempt = 0; attempt < 150; attempt++)); do
  url=$(sed -n 's/^dsh web: //p' "$test_dir/server.log" | head -n 1)
  if [[ -n "$url" ]]; then
    curl --fail --silent --show-error --location --max-time 10 \
      --cookie-jar "$test_dir/cookies" --cookie "$test_dir/cookies" \
      "$url" -o "$test_dir/page.html"
    if ! grep -qi '<html' "$test_dir/page.html"; then
      echo 'DSH returned no HTML page.' >&2
      exit 1
    fi
    echo 'DSH profile boots and serves its authenticated Web UI.'
    exit 0
  fi
  if ! kill -0 "$server_pid" 2>/dev/null; then
    break
  fi
  sleep 0.2
done

sed -E 's/token=[^[:space:]]+/token=<redacted>/g' "$test_dir/server.log" >&2
echo 'DSH did not start its Web UI.' >&2
exit 1
