# Load approved project environments for noninteractive Bash and Zsh shells.
# Devenv and direnv own environment caching and dependency/trust checks.

_agent_env_hook() {
  case $- in
    *i*) return 0 ;;
  esac
  [ "${AGENT_ENV_DISABLE:-0}" = "1" ] && return 0
  [ "${AGENT_ENV_LOADING:-0}" = "1" ] && return 0
  [ -n "${NIX_BUILD_TOP:-}" ] && return 0
  command -v direnv >/dev/null 2>&1 || return 0

  local root="$PWD"
  while [ -n "$root" ] && [ "$root" != "/" ] && [ ! -e "$root/.envrc" ]; do
    root="${root%/*}"
  done
  [ -e "$root/.envrc" ] || return 0

  local environment error_log
  error_log="$(mktemp "${TMPDIR:-/tmp}/agent-env.XXXXXX")" || return 0
  if environment="$(
    exec 2>"$error_log"
    # Recheck even when inherited flags say the environment is unchanged.
    # Keep DIRENV_DIFF so direnv can undo exports from the previous project.
    unset DIRENV_WATCHES
    export AGENT_ENV_LOADING=1
    if command -v timeout >/dev/null 2>&1; then
      timeout 120s direnv export bash
    else
      direnv export bash
    fi
  )"; then
    eval "$environment"
    rm -f "$error_log"
  else
    printf 'agent-env: could not load %s/.envrc, see %s\n' "$root" "$error_log" >&2
  fi
  return 0
}

_agent_env_hook
unset -f _agent_env_hook
