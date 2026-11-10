{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.core.cache-cleanup;
  inherit (constants) isDarwin isLinux homeDir;
  logDir =
    if isDarwin then
      "${homeDir}/Library/Logs/rgo-cache-cleanup"
    else
      "${homeDir}/.local/state/rgo-maintenance";
  stateDir =
    if isDarwin then
      "${homeDir}/Library/Application Support/rgo-maintenance"
    else
      "${homeDir}/.local/state/rgo-maintenance";

  cleanupScript = pkgs.writeShellApplication {
    name = "rgo-cache-cleanup";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gawk
      pkgs.findutils
      pkgs.procps
    ];
    text = ''
      export PATH="/opt/homebrew/bin:/usr/local/bin:${homeDir}/.local/bin:${homeDir}/.nix-profile/bin:/etc/profiles/per-user/${username}/bin:/run/current-system/sw/bin:$PATH"
      export LANG="en_US.UTF-8"

      # User caches must never acquire root-owned logs or maintenance state.
      if [ "$(id -u)" = 0 ]; then
        printf 'Run rgo-cache-cleanup as ${username}, not root.\n' >&2
        exit 1
      fi

      force=0
      pressure=0
      case "''${1:-}" in
        "" | normal)
          ;;
        --force)
          force=1
          ;;
        --pressure)
          force=1
          pressure=1
          ;;
        *)
          printf 'usage: rgo-cache-cleanup [--force|--pressure]\n' >&2
          exit 2
          ;;
      esac

      user_home=${lib.escapeShellArg homeDir}
      xdg_cache_home="''${XDG_CACHE_HOME:-$user_home/.cache}"
      interval_seconds=${toString cfg.intervalSeconds}
      managed_cache_days=${toString cfg.managedCacheRetentionDays}
      auto_pressure=${if cfg.autoPressure.enable then "1" else "0"}
      pressure_free_gib=${toString cfg.pressureFreeGiB}
      pressure_recovery_gib=${toString cfg.autoPressure.recoveryFreeGiB}
      pressure_cooldown_seconds=${toString cfg.autoPressure.cooldownSeconds}
      bun_max_gib=${toString cfg.bun.maxSizeGiB}
      npm_max_gib=${toString cfg.npm.maxSizeGiB}
      docker_build_max_gib=${toString cfg.dockerBuild.maxSizeGiB}
      docker_build_reserved_gib=2
      report_min_kib=$((1024 * 1024))
      log_dir=${lib.escapeShellArg logDir}
      state_dir=${lib.escapeShellArg stateDir}
      log_file="$log_dir/cache-cleanup.log"
      stamp_file="$state_dir/cache-cleanup.last-success"
      failures=0

      mkdir -p "$log_dir" "$state_dir"
      exec >>"$log_file" 2>&1

      log() {
        printf '[%s] rgo-cache-cleanup: %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*"
      }

      run() {
        if pressure_target_reached; then
          log "pressure recovery target reached; skipping: $*"
          return 0
        fi
        log "running: $*"
        if "$@"; then
          return 0
        else
          status=$?
          failures=$((failures + 1))
          log "warning: command failed with status=$status: $*"
          return 0
        fi
      }

      ${builtins.readFile ./policy.sh}

      cache_exceeds_limit() {
        dir=$1
        max_gib=$2

        if [ ! -d "$dir" ] || pressure_target_reached; then
          return 1
        fi
        if [ "$pressure" = "1" ]; then
          return 0
        fi

        size_bytes=$(du -s -B1 "$dir" 2>/dev/null | cut -f1 || true)
        max_bytes=$((max_gib * 1024 * 1024 * 1024))
        [ "''${size_bytes:-0}" -gt "$max_bytes" ]
      }

      process_running() {
        pgrep -u "$(id -u)" -f "$1" >/dev/null 2>&1
      }

      prune_top_level_by_age() {
        dir=$1
        days=$2
        if [ -d "$dir" ]; then
          log "removing top-level entries in $dir older than $days days"
          run find "$dir" -xdev -mindepth 1 -maxdepth 1 -mtime +"$days" -exec rm -rf -- {} +
        fi
      }

      now=$(date +%s)
      configure_pressure
      if [ "$force" = "0" ] && [ -f "$stamp_file" ]; then
        last_success=$(cat "$stamp_file" 2>/dev/null || true)
        case "$last_success" in
          *[!0-9]* | "")
            log "ignoring invalid success stamp: $last_success"
            ;;
          *)
            age=$((now - last_success))
            if [ "$age" -lt "$interval_seconds" ]; then
              log "skipping: last successful run was $age seconds ago"
              exit 0
            fi
            ;;
        esac
      fi

      log "started force=$force pressure=$pressure"

      # Tool-managed caches that bound themselves are deliberately absent:
      # Go build cache (trims entries unused for 5 days), Go modules, Gradle
      # (own 30-day cleanup), Playwright browsers, uv, Nix, model weights.

      if command -v brew >/dev/null 2>&1; then
        export HOMEBREW_NO_AUTO_UPDATE=1
        run brew cleanup --prune="$managed_cache_days"
      fi

      if process_running '(^|/)(bun)( |$).*(install|add|update|x )|(^|/)bunx( |$)'; then
        log "keeping Bun cache while a package operation is active"
      else
        # BUN_INSTALL_CACHE_DIR is unset here, so Bun uses one of these.
        for bun_cache in "$xdg_cache_home/.bun/install/cache" "$user_home/.bun/install/cache"; do
          if cache_exceeds_limit "$bun_cache" "$bun_max_gib"; then
            prune_cache_entries "$bun_cache"
          fi
        done
      fi

      if process_running '(^|/)(npm|npx)( |$)'; then
        log "keeping npm cache while a package operation is active"
      elif command -v npm >/dev/null 2>&1; then
        if cache_exceeds_limit "$user_home/.npm/_cacache" "$npm_max_gib"; then
          prune_managed_cache "$user_home/.npm/_cacache"
        fi
        # Drops index entries whose content is gone and unreferenced content.
        run npm cache verify
        prune_top_level_by_age "$user_home/.npm/_npx" 14
      fi

      ${lib.concatMapStringsSep "\n" (cache: ''
        if process_running ${lib.escapeShellArg cache.processPattern}; then
          log ${lib.escapeShellArg "keeping ${cache.name} cache while its writer is active"}
        elif cache_exceeds_limit ${lib.escapeShellArg cache.directory} ${toString cache.maxSizeGiB}; then
          prune_managed_cache ${lib.escapeShellArg cache.directory}
        fi
      '') cfg.userCache.boundedDirectories}

      # Interrupted Go commands leave their work directories behind.
      if ! process_running '(^|/)(go)( |$)'; then
        ${lib.optionalString isLinux ''
          run find /tmp -xdev -mindepth 1 -maxdepth 1 -type d -user "$(id -u)" -name 'go-build*' -mtime +1 -exec rm -rf -- {} +
        ''}
        ${lib.optionalString isDarwin ''
          darwin_tmp=$(/usr/bin/getconf DARWIN_USER_TEMP_DIR 2>/dev/null || true)
          if [ -n "$darwin_tmp" ]; then
            run find "$darwin_tmp" -xdev -mindepth 1 -maxdepth 1 -type d -user "$(id -u)" -name 'go-build*' -mtime +1 -exec rm -rf -- {} +
          fi
        ''}
      fi

      # devenv writes a shell-<hash>.sh for every invocation and never removes
      # it. One checkout reached 16k files and 1.6GB before this sweep existed.
      for devenv_state in "$user_home"/dev/*/.devenv "$user_home"/.t3/worktrees/*/*/.devenv; do
        [ -d "$devenv_state" ] || continue
        run find "$devenv_state" -xdev -maxdepth 1 -type f -name 'shell-*.sh' -mtime +1 -delete
      done

      ${lib.optionalString isDarwin ''
        prune_top_level_by_age "$user_home/Library/Developer/Xcode/DerivedData" 14
        prune_top_level_by_age "$user_home/Library/Application Support/BeeperTexts/api-uploads" 1
        # Sparkle leaves extracted updates behind; a week-old one is stale and
        # the updater downloads it again if needed.
        for sparkle_staging in "$user_home"/Library/Caches/*/org.sparkle-project.Sparkle/Installation; do
          prune_top_level_by_age "$sparkle_staging" 7
        done
      ''}

      # BuildKit evicts least recently used build cache itself; images and
      # volumes are never touched. Skip quietly when no daemon is running.
      if command -v docker >/dev/null 2>&1 && timeout 15 docker info >/dev/null 2>&1; then
        docker_args=(
          --force
          --max-used-space "''${docker_build_max_gib}gb"
          --reserved-space "''${docker_build_reserved_gib}gb"
        )
        if [ "$pressure" = "1" ]; then
          docker_args+=(--min-free-space "''${pressure_free_gib}gb")
        fi
        run docker builder prune "''${docker_args[@]}"
      fi

      report_manual_candidates "agent scratch" "$user_home"/dev/*/tmp
      report_manual_candidates "git worktrees" "$user_home"/.t3/worktrees "$user_home"/.codex/worktrees "$user_home"/.claude/worktrees
      report_manual_candidates "agent session history" "$user_home"/.codex/sessions "$user_home"/.claude/projects

      if [ "$pressure" = 1 ] && ! pressure_target_reached; then
        log "warning: cleanup could not reach the $pressure_recovery_gib GiB recovery target; recent caches were retained"
      fi

      if [ "$failures" -eq 0 ]; then
        printf '%s\n' "$now" >"$stamp_file"
        log "finished successfully"
      else
        log "finished with $failures failed step(s); success stamp not updated"
        exit 1
      fi
    '';
  };
in
{
  options.core.cache-cleanup = {
    enable = lib.mkEnableOption "periodic user cache cleanup";

    intervalSeconds = lib.mkOption {
      type = lib.types.ints.positive;
      default = 604800;
      description = "Run cache cleanup this many seconds after the previous run.";
    };

    pressureFreeGiB = lib.mkOption {
      type = lib.types.ints.positive;
      default = 64;
      description = "Free-space floor used by automatic and explicit pressure cleanup.";
    };

    autoPressure.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Run pressure cleanup even inside the normal interval when free space is below the configured floor.";
    };

    autoPressure.recoveryFreeGiB = lib.mkOption {
      type = lib.types.ints.positive;
      default = cfg.pressureFreeGiB + 8;
      description = "Stop pressure eviction after recovering this much free space.";
    };

    autoPressure.cooldownSeconds = lib.mkOption {
      type = lib.types.ints.positive;
      default = 259200;
      description = "Minimum time between automatic pressure attempts, including failed runs.";
    };

    managedCacheRetentionDays = lib.mkOption {
      type = lib.types.ints.positive;
      default = 30;
      description = "Preserve package and build cache entries used or written within this many days, even under pressure. Size limits trigger age-bounded pruning, not full deletion.";
    };

    bun.maxSizeGiB = lib.mkOption {
      type = lib.types.ints.positive;
      default = 6;
      description = "Prune old Bun package entries once the cache grows beyond this size.";
    };

    npm.maxSizeGiB = lib.mkOption {
      type = lib.types.ints.positive;
      default = 4;
      description = "Prune old npm content once the cache grows beyond this size.";
    };

    userCache.boundedDirectories = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            name = lib.mkOption { type = lib.types.str; };
            directory = lib.mkOption { type = lib.types.str; };
            processPattern = lib.mkOption { type = lib.types.str; };
            maxSizeGiB = lib.mkOption {
              type = lib.types.ints.positive;
              default = 1;
            };
          };
        }
      );
      default = [ ];
      description = "Caches that never evict on their own and whose files are independent entries, so single-file pruning is a cache miss. Never list package stores that unpack directories, databases, browser profiles, installed runtimes or model weights.";
    };

    dockerBuild.maxSizeGiB = lib.mkOption {
      type = lib.types.ints.positive;
      default = 10;
      description = "Maximum Docker build-cache size retained when a Docker daemon is running.";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isDarwin {
        launchd.agents.cache-cleanup = {
          serviceConfig = {
            ProgramArguments = [ "${cleanupScript}/bin/rgo-cache-cleanup" ];
            RunAtLoad = true;
            StartInterval = 86400;
            EnvironmentVariables.HOME = homeDir;
            ProcessType = "Background";
            LowPriorityIO = true;
            Nice = 10;
            StandardOutPath = "/tmp/rgo-cache-cleanup.log";
            StandardErrorPath = "/tmp/rgo-cache-cleanup.err";
          };
        };
      })

      {
        home-manager.users.${username} =
          _:
          lib.mkIf isLinux {
            systemd.user.services.rgo-cache-cleanup = {
              Unit = {
                Description = "Clean safe user caches";
              };
              Service = {
                Type = "oneshot";
                ExecStart = "${cleanupScript}/bin/rgo-cache-cleanup";
              };
            };

            systemd.user.timers.rgo-cache-cleanup = {
              Unit = {
                Description = "Run safe user cache cleanup";
              };
              Timer = {
                OnBootSec = "15m";
                OnUnitActiveSec = "1d";
                RandomizedDelaySec = "1h";
                Persistent = true;
                Unit = "rgo-cache-cleanup.service";
              };
              Install = {
                WantedBy = [ "timers.target" ];
              };
            };
          };
      }
    ]
  );
}
