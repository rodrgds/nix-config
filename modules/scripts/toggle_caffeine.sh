#!/usr/bin/env bash
# Keep-awake toggle shared by the bar buttons on macOS and Linux.
# Toggling starts or stops a keeper process and remembers its PID in a
# runtime file; "status" reports without changing anything. stdout is
# always "on" or "off" so the bar renderers can restyle the button.
#
# macOS keeps the whole machine awake with caffeinate; Linux takes a
# logind idle inhibitor, which hypridle respects (ignore_dbus_inhibit is
# false), so the session neither locks nor blanks while it is held.

set -u

state_file="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/rgo-caffeinate.pid"

is_darwin() {
  [[ "$(uname)" == "Darwin" ]]
}

keeper_name() {
  if is_darwin; then
    printf 'caffeinate'
  else
    printf 'systemd-inhibit'
  fi
}

keeper_pid() {
  local pid
  pid=$(head -n 1 "$state_file" 2>/dev/null) || return 1
  [[ ${pid:-} =~ ^[0-9]+$ ]] || return 1
  kill -0 "$pid" 2>/dev/null || return 1
  # A recycled PID must never be mistaken for our keeper process.
  [[ "$(basename "$(ps -p "$pid" -o comm= 2>/dev/null)")" == "$(keeper_name)" ]] || return 1
  printf '%s' "$pid"
}

start_keeper() {
  if is_darwin; then
    caffeinate -dims </dev/null >/dev/null 2>&1 &
  else
    systemd-inhibit --what=idle --mode=block sleep infinity </dev/null >/dev/null 2>&1 &
  fi
  printf '%s\n' "$!" >"$state_file"
}

stop_keeper() {
  local pid
  if pid=$(keeper_pid); then
    pkill -P "$pid" 2>/dev/null
    kill "$pid" 2>/dev/null
  fi
  rm -f "$state_file"
}

report_state() {
  if keeper_pid >/dev/null; then
    printf 'on\n'
  else
    printf 'off\n'
  fi
}

case "${1:-toggle}" in
status)
  report_state
  ;;
toggle)
  local_state=off
  message="Machine can sleep and lock again"
  if keeper_pid >/dev/null; then
    stop_keeper
  else
    start_keeper
    local_state=on
    message="Machine stays awake until you click the cup again"
  fi
  if ! is_darwin && command -v notify-send >/dev/null 2>&1; then
    notify-send -a "Caffeine" "Caffeine ${local_state}" "$message"
  fi
  report_state
  ;;
*)
  printf 'usage: %s [status]\n' "$0" >&2
  exit 2
  ;;
esac
