# Load the project's direnv/devenv environment once per project and reuse it.
#
# Agent shells start in the project directory and run with `bash -lc`. Asking
# every command to pay `devenv shell` startup is the single largest source of
# avoidable agent latency in this setup. Instead, export the environment once,
# cache it per project, and source the cache (~10ms) on later commands.
#
# Sourced from the login profile, so it must never fail a shell.

_agent_env_mtime() {
  stat -f '%m' "$1" 2>/dev/null || stat -c '%Y' "$1" 2>/dev/null || printf '0'
}

_agent_env_hash() {
  if command -v shasum >/dev/null 2>&1; then
    printf '%s' "$1" | shasum -a 1 | cut -c1-20
  elif command -v sha1sum >/dev/null 2>&1; then
    printf '%s' "$1" | sha1sum | cut -c1-20
  else
    printf '%s' "$1" | cksum | cut -d' ' -f1
  fi
}

_agent_env_hook() {
  # Interactive shells must never pay the direnv export, and some devenv
  # versions open a TUI when they detect a TTY, which hangs the prompt.
  case $- in
    *i*) return 0 ;;
  esac

  # Already inside an activated environment, a build, or an explicit opt-out.
  [ -n "${AGENT_ENV_LOADED:-}" ] && return 0
  [ -n "${DEVENV_ROOT:-}" ] && return 0
  [ -n "${DIRENV_DIR:-}" ] && return 0
  [ -n "${IN_NIX_SHELL:-}" ] && return 0
  [ -n "${NIX_BUILD_TOP:-}" ] && return 0
  [ "${AGENT_ENV_DISABLE:-0}" = "1" ] && return 0
  command -v direnv >/dev/null 2>&1 || return 0

  local root="$PWD"
  while [ "$root" != "/" ] && [ ! -e "$root/.envrc" ]; do
    root="${root%/*}"
  done
  [ -e "$root/.envrc" ] || return 0

  local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/agent-env"
  local cache="$cache_dir/$(_agent_env_hash "$root").sh"
  local stamp
  stamp="$(_agent_env_mtime "$root/.envrc")"
  local file
  for file in devenv.nix devenv.lock devenv.yaml .env; do
    [ -e "$root/$file" ] && stamp="$stamp:$(_agent_env_mtime "$root/$file")"
  done

  local header
  header="$(head -n 1 "$cache" 2>/dev/null || true)"
  local now
  now="$(date +%s)"

  case "$header" in
    "# agent-env ok $stamp")
      . "$cache"
      export AGENT_ENV_LOADED=1
      return 0
      ;;
    "# agent-env fail $stamp "*)
      local failed_at="${header##* }"
      if [ $((now - failed_at)) -lt 300 ]; then
        export AGENT_ENV_LOADED=1
        return 0
      fi
      ;;
  esac

  mkdir -p "$cache_dir" 2>/dev/null || return 0
  chmod 700 "$cache_dir" 2>/dev/null || true
  local temporary="$cache.$$"
  local exporter=(direnv export bash)
  command -v timeout >/dev/null 2>&1 && exporter=(timeout 120 direnv export bash)

  if (
    umask 077
    cd "$root" || exit 1
    "${exporter[@]}" >"$temporary.body" 2>/dev/null || exit 1
    {
      printf '# agent-env ok %s\n' "$stamp"
      cat "$temporary.body"
    } >"$temporary"
  ); then
    mv "$temporary" "$cache" 2>/dev/null
  else
    printf '# agent-env fail %s %s\n' "$stamp" "$now" >"$cache" 2>/dev/null
  fi
  rm -f "$temporary.body" "$temporary" 2>/dev/null

  if [ "$(head -n 1 "$cache" 2>/dev/null || true)" = "# agent-env ok $stamp" ]; then
    . "$cache"
  fi
  export AGENT_ENV_LOADED=1
  return 0
}

_agent_env_hook
unset -f _agent_env_hook _agent_env_hash _agent_env_mtime
