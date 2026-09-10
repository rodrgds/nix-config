#!/usr/bin/env bash

set -u

sample_seconds=0
case "${1:-}" in
  "") ;;
  --sample)
    sample_seconds="${2:-10}"
    if [[ ! "$sample_seconds" =~ ^([1-9]|[1-5][0-9]|60)$ ]] || [ "$#" -gt 2 ]; then
      printf 'Sample duration must be an integer from 1 to 60 seconds.\n' >&2
      exit 2
    fi
    ;;
  *) printf 'Usage: rgo-laptop-health [--sample [1..60 seconds]]\n' >&2; exit 2 ;;
esac

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
  local output pid rss_kib attempt

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

check_absent_agent() {
  local label="$1" name="$2" process="$3"
  if launchctl print "gui/$(id -u)/$label" >/dev/null 2>&1 || pgrep -x "$process" >/dev/null; then
    fail "$name is disabled but still loaded or running"
  else
    ok "$name is disabled and absent"
  fi
}

if "$health_sketchybar"; then
  check_launchd_agent org.nix-community.home.sketchybar SketchyBar 131072
  if command -v sketchybar >/dev/null 2>&1 && sketchybar --query bar >/dev/null 2>&1; then
    ok "SketchyBar answers queries"
  else
    fail "SketchyBar does not answer queries"
  fi
else
  check_absent_agent org.nix-community.home.sketchybar SketchyBar sketchybar
  menu_hidden="$(defaults read NSGlobalDomain _HIHideMenuBar 2>/dev/null || printf '0')"
  if [ "$menu_hidden" = 0 ]; then
    ok "Native menu bar is configured to stay visible"
  else
    fail "Native menu bar is configured to hide"
  fi
fi

if "$health_borders"; then
  check_launchd_agent dev.rgo.borders Borders 98304
else
  check_absent_agent dev.rgo.borders Borders rgo-borders
fi

if "$health_keepingyouawake"; then
  check_launchd_agent org.nix-community.home.keepingyouawake KeepingYouAwake 131072
else
  check_absent_agent org.nix-community.home.keepingyouawake KeepingYouAwake KeepingYouAwake
fi

if "$health_stats"; then
  check_launchd_agent org.nix-community.home.stats Stats 262144
else
  check_absent_agent org.nix-community.home.stats Stats Stats
fi

if "$health_macshot"; then
  check_launchd_agent org.nix-community.home.macshot Macshot 262144
else
  check_absent_agent org.nix-community.home.macshot Macshot macshot
fi

# The legacy border process can survive a configuration change.
if pgrep -x borders >/dev/null || pgrep -ix jankyborders >/dev/null; then
  fail "A legacy border process is running alongside the configured desktop"
fi
sketchybar_count="$(pgrep -x sketchybar | wc -l | tr -d ' ')"
if [ "$sketchybar_count" -gt 1 ]; then
  fail "Multiple SketchyBar processes are running ($sketchybar_count)"
fi

if "$health_aerospace"; then
  if /opt/homebrew/bin/aerospace list-workspaces --focused >/dev/null 2>&1; then
    ok "AeroSpace accepts commands"
  else
    fail "AeroSpace does not accept commands"
  fi
fi

if "$health_brave"; then
  if command -v duti >/dev/null 2>&1; then
    browser_handler="$(duti -d https 2>/dev/null || true)"
    if [ "$browser_handler" = "com.brave.Browser" ]; then
      ok "Brave is the default web browser"
    else
      fail "Brave is not the default web browser"
    fi
  else
    fail "duti is unavailable, so the default web browser cannot be checked"
  fi
fi

if "$health_vicinae"; then
  if /opt/homebrew/bin/vicinae ping >/dev/null 2>&1; then
    ok "Vicinae answers ping"
  else
    warn "Vicinae is stopped. Unlock the login keychain, then run vicinae-launcher"
  fi
fi

firewall_state="$(/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null || true)"
if printf '%s\n' "$firewall_state" | grep -Fq 'enabled'; then
  ok "Application firewall is enabled"
else
  fail "Application firewall is disabled"
fi

stealth_state="$(/usr/libexec/ApplicationFirewall/socketfilterfw --getstealthmode 2>/dev/null || true)"
if printf '%s\n' "$stealth_state" | grep -Eq 'enabled|is on'; then
  ok "Firewall stealth mode is enabled"
else
  fail "Firewall stealth mode is disabled"
fi

if grep -Fq 'pam_tid.so' /etc/pam.d/sudo_local 2>/dev/null; then
  ok "Touch ID sudo is configured"
else
  fail "Touch ID sudo is not configured"
fi

free_kib="$(df -Pk /System/Volumes/Data | awk 'NR == 2 { print $4 }')"
low_space_kib=$((16 * 1024 * 1024))
if [[ ! "$free_kib" =~ ^[0-9]+$ ]]; then
  warn "Could not read free space on the data volume"
elif [ "$free_kib" -lt "$low_space_kib" ]; then
  warn "Data volume has $((free_kib / 1024)) MiB available, below 16 GiB"
else
  ok "Data volume has $((free_kib / 1024 / 1024)) GiB available"
fi

if [ "$sample_seconds" -gt 0 ]; then
  sample_dir="$(mktemp -d)" || exit 1
  trap 'rm -rf "$sample_dir"' EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  printf '\nSampling process CPU time for %s seconds. Keep workload and display settings comparable.\n' "$sample_seconds"
  # Two snapshots avoid continuous polling. Exited and short-lived processes are not measured.
  ps -axo pid=,time=,rss=,comm= > "$sample_dir/before" || exit 1
  sample_start="$(date +%s)"
  sleep "$sample_seconds"
  ps -axo pid=,time=,rss=,comm= > "$sample_dir/after" || exit 1
  elapsed=$(( $(date +%s) - sample_start ))
  printf 'PID     CPU seconds  CPU %% of one core  RSS MiB  Process\n'
  awk -v elapsed="$elapsed" '
    function seconds(value, parts, count, total, i) {
      count = split(value, parts, ":")
      total = 0
      for (i = 1; i <= count; i++) total = total * 60 + parts[i]
      return total
    }
    NR == FNR { cpu[$1] = seconds($2); command[$1] = $4; next }
    ($1 in cpu) && command[$1] == $4 {
      delta = seconds($2) - cpu[$1]
      name = $0
      sub(/^[[:space:]]*[0-9]+[[:space:]]+[^[:space:]]+[[:space:]]+[0-9]+[[:space:]]+/, "", name)
      if (delta >= 0 && elapsed > 0)
        printf "%7d %11.2f %18.1f %8.1f  %s\n", $1, delta, 100 * delta / elapsed, $3 / 1024, name
    }
  ' "$sample_dir/before" "$sample_dir/after" | sort -k2,2nr
  printf 'Elapsed: %s seconds. RSS is resident memory, not physical footprint or total app memory.\n' "$elapsed"
  printf 'This sample does not measure energy, latency, or process creation counts.\n'
fi

printf '\n%d failure(s), %d warning(s)\n' "$failures" "$warnings"
if [ "$failures" -gt 0 ]; then
  exit 1
fi
