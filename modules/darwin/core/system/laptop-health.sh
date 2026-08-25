#!/usr/bin/env bash

set -u

failures=0
warnings=0

ok() {
  printf 'OK    %s\n' "$1"
}

warn() {
  printf 'WARN  %s\n' "$1"
  warnings=$((warnings + 1))
}

fail() {
  printf 'FAIL  %s\n' "$1"
  failures=$((failures + 1))
}

check_launchd_agent() {
  local label="$1"
  local name="$2"
  local max_rss_kib="$3"
  local output pid rss_kib

  pid=""
  attempt=0
  while [ "$attempt" -lt 20 ]; do
    output="$(launchctl print "gui/$(id -u)/$label" 2>/dev/null || true)"
    pid="$(printf '%s\n' "$output" | awk '/^[[:space:]]*pid = / { print $3; exit }')"
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then break; fi
    sleep 0.25
    attempt=$((attempt + 1))
  done
  if [ -z "$pid" ] || ! kill -0 "$pid" 2>/dev/null; then
    fail "$name is not running ($label)"
    return
  fi

  rss_kib="$(ps -o rss= -p "$pid" | tr -d ' ')"
  if [ -n "$rss_kib" ] && [ "$rss_kib" -gt "$max_rss_kib" ]; then
    warn "$name is running as PID $pid but RSS is $((rss_kib / 1024)) MiB"
  else
    ok "$name is running as PID $pid"
  fi
}

check_launchd_agent org.nix-community.home.sketchybar SketchyBar 131072
check_launchd_agent dev.rgo.borders Borders 98304

if /opt/homebrew/bin/aerospace list-workspaces --focused >/dev/null 2>&1; then
  ok "AeroSpace accepts commands"
else
  fail "AeroSpace does not accept commands"
fi

if command -v sketchybar >/dev/null 2>&1 && sketchybar --query bar >/dev/null 2>&1; then
  ok "SketchyBar answers queries"
else
  fail "SketchyBar does not answer queries"
fi

if /opt/homebrew/bin/vicinae ping >/dev/null 2>&1; then
  ok "Vicinae answers ping"
else
  warn "Vicinae is stopped. Unlock the login keychain, then run vicinae-launcher"
fi

firewall_state="$(/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null || true)"
if printf '%s\n' "$firewall_state" | grep -Fq 'enabled'; then
  ok "Application firewall is enabled"
else
  fail "Application firewall is disabled"
fi

stealth_state="$(/usr/libexec/ApplicationFirewall/socketfilterfw --getstealthmode 2>/dev/null || true)"
if printf '%s\n' "$stealth_state" | grep -Fq 'enabled'; then
  ok "Firewall stealth mode is enabled"
else
  fail "Firewall stealth mode is disabled"
fi

if grep -Fq 'pam_tid.so' /etc/pam.d/sudo_local 2>/dev/null; then
  ok "Touch ID sudo is configured"
else
  fail "Touch ID sudo is not configured"
fi

printf '\n%d failure(s), %d warning(s)\n' "$failures" "$warnings"
if [ "$failures" -gt 0 ]; then
  exit 1
fi
