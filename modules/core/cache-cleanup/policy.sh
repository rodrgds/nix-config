available_gib() {
  df -B1 --output=avail "$user_home" 2>/dev/null | tail -n 1 | awk '{ if ($1 ~ /^[0-9]+$/) print int($1 / 1073741824) }'
}

configure_pressure() {
  local available last_attempt
  available=$(available_gib || true)
  case "$available" in *[!0-9]* | "") return 0 ;; esac
  if [ "$available" -ge "$pressure_recovery_gib" ]; then
    rm -f "$state_dir/cache-cleanup.pressure-active"
  fi
  if [ "$auto_pressure" != 1 ] || [ "$pressure" = 1 ]; then
    return 0
  fi
  if [ "$available" -ge "$pressure_free_gib" ] && [ ! -e "$state_dir/cache-cleanup.pressure-active" ]; then
    return 0
  fi
  log "warning: low disk space: ${available} GiB free; recovery target ${pressure_recovery_gib} GiB"
  last_attempt=$(cat "$state_dir/cache-cleanup.pressure-attempt" 2>/dev/null || true)
  case "$last_attempt" in
    *[!0-9]* | "") ;;
    *)
      if [ "$((now - last_attempt))" -lt "$pressure_cooldown_seconds" ]; then
        log "automatic pressure cleanup is cooling down"
        return 0
      fi
      ;;
  esac
  pressure=1
  force=1
  touch "$state_dir/cache-cleanup.pressure-active"
  # Record attempts, including partial failures, so a broken step cannot cause daily sweeps.
  printf '%s\n' "$now" >"$state_dir/cache-cleanup.pressure-attempt"
}

pressure_target_reached() {
  local available
  [ "$pressure" = 1 ] || return 1
  available=$(available_gib || true)
  case "$available" in *[!0-9]* | "") return 1 ;; esac
  [ "$available" -ge "$pressure_recovery_gib" ] || return 1
  rm -f "$state_dir/cache-cleanup.pressure-active"
  return 0
}

prune_managed_cache() {
  local cache_dir=$1
  [ -d "$cache_dir" ] || return 0
  pressure_target_reached && return 0
  log "pruning cache files unused for $managed_cache_days days at $cache_dir"
  run find "$cache_dir" -xdev -type f -atime +"$managed_cache_days" -mtime +"$managed_cache_days" -delete
}
