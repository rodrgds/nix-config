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
      "${homeDir}/Library/Logs/rgo-maintenance"
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
      pkgs.findutils
      pkgs.procps
    ];
    text = ''
      export PATH="/opt/homebrew/bin:/usr/local/bin:${homeDir}/.local/bin:${homeDir}/.nix-profile/bin:/etc/profiles/per-user/${username}/bin:/run/current-system/sw/bin:$PATH"
      export LANG="en_US.UTF-8"

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

      home=${lib.escapeShellArg homeDir}
      interval_seconds=${toString cfg.intervalSeconds}
      transient_days=${toString cfg.transientRetentionDays}
      npx_days=${toString cfg.npxRetentionDays}
      derived_data_days=${toString cfg.xcodeDerivedDataRetentionDays}
      user_cache_days=${toString cfg.userCacheRetentionDays}
      do_homebrew=${if cfg.homebrew.enable then "1" else "0"}
      do_beeper_uploads=${if cfg.beeperUploads.enable then "1" else "0"}
      do_bun=${if cfg.bun.enable then "1" else "0"}
      do_npm=${if cfg.npm.enable then "1" else "0"}
      do_pnpm=${if cfg.pnpm.enable then "1" else "0"}
      do_gradle=${if cfg.gradle.enable then "1" else "0"}
      do_xcode=${if cfg.xcodeDerivedData.enable then "1" else "0"}
      do_cocoapods=${if cfg.cocoapods.enable then "1" else "0"}
      do_user_cache=${if cfg.userCache.enable then "1" else "0"}
      do_go_builds=${if cfg.goBuilds.enable then "1" else "0"}
      do_go_build_cache=${if cfg.goBuildCache.enable then "1" else "0"}
      do_docker_build=${if cfg.dockerBuild.enable then "1" else "0"}
      auto_pressure=${if cfg.autoPressure.enable then "1" else "0"}
      bun_max_gib=${toString cfg.bun.maxSizeGiB}
      npm_max_gib=${toString cfg.npm.maxSizeGiB}
      gradle_max_gib=${toString cfg.gradle.maxSizeGiB}
      go_build_cache_max_gib=${toString cfg.goBuildCache.maxSizeGiB}
      docker_build_max_gib=${toString cfg.dockerBuild.maxSizeGiB}
      docker_build_reserved_gib=${toString cfg.dockerBuild.reservedSizeGiB}
      pressure_free_gib=${toString cfg.pressureFreeGiB}
      log_dir=${lib.escapeShellArg logDir}
      state_dir=${lib.escapeShellArg stateDir}
      log_file="$log_dir/cache-cleanup.log"
      stamp_file="$state_dir/cache-cleanup.last-success"
      failures=0
      auto_pressure_triggered=0

      if [ "$auto_pressure" = "1" ] && [ "$pressure" = "0" ]; then
        available_bytes=$(df -B1 --output=avail "$home" 2>/dev/null | tail -n 1 | tr -d ' ' || true)
        pressure_bytes=$((pressure_free_gib * 1024 * 1024 * 1024))
        case "$available_bytes" in
          *[!0-9]* | "")
            ;;
          *)
            if [ "$available_bytes" -lt "$pressure_bytes" ]; then
              force=1
              pressure=1
              auto_pressure_triggered=1
            fi
            ;;
        esac
      fi

      mkdir -p "$log_dir" "$state_dir"
      exec >>"$log_file" 2>&1

      log() {
        printf '[%s] rgo-cache-cleanup: %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*"
      }

      run() {
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

      cache_exceeds_limit() {
        dir=$1
        max_gib=$2

        if [ "$pressure" = "1" ]; then
          return 0
        fi

        if [ ! -d "$dir" ]; then
          return 1
        fi

        size_bytes=$(du -s -B1 "$dir" 2>/dev/null | cut -f1 || true)
        max_bytes=$((max_gib * 1024 * 1024 * 1024))
        [ "''${size_bytes:-0}" -gt "$max_bytes" ]
      }

      clear_cache_dir() {
        label=$1
        dir=$2
        max_gib=$3

        if cache_exceeds_limit "$dir" "$max_gib"; then
          log "clearing $label cache at $dir (pressure mode or over ''${max_gib} GiB)"
          if [ -d "$dir" ]; then
            run find "$dir" -xdev -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
          fi
        else
          log "keeping $label cache at or below ''${max_gib} GiB"
        fi
      }

      process_running() {
        pgrep -u "$(id -u)" -f "$1" >/dev/null 2>&1
      }

      clean_go_cache() {
        dir=$1

        if [ ! -d "$dir" ]; then
          return 0
        fi

        if cache_exceeds_limit "$dir" "$go_build_cache_max_gib"; then
          log "clearing Go build cache at $dir (pressure mode or over ''${go_build_cache_max_gib} GiB)"
          run env GOCACHE="$dir" go clean -cache
        else
          log "keeping Go build cache at $dir at or below ''${go_build_cache_max_gib} GiB"
        fi
      }

      prune_top_level_by_age() {
        dir=$1
        days=$2
        if [ -d "$dir" ]; then
          log "removing top-level entries in $dir older than $days days"
          run find "$dir" -xdev -mindepth 1 -maxdepth 1 -mtime +"$days" -exec rm -rf -- {} +
        fi
      }

      prune_cache_files_by_age() {
        dir=$1
        days=$2
        if [ -d "$dir" ]; then
          log "removing files in $dir not accessed or modified for $days days"
          run find "$dir" -xdev -type f -atime +"$days" -mtime +"$days" -delete
          run find "$dir" -xdev -depth -mindepth 1 -type d -empty -delete
        fi
      }

      prune_named_top_level_by_age() {
        dir=$1
        pattern=$2
        days=$3
        if [ -d "$dir" ]; then
          log "removing $pattern entries in $dir older than $days days"
          run find "$dir" -xdev -mindepth 1 -maxdepth 1 -type d -user "$(id -u)" -name "$pattern" -mtime +"$days" -exec rm -rf -- {} +
        fi
      }

      now=$(date +%s)
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

      log "started force=$force pressure=$pressure auto_pressure_triggered=$auto_pressure_triggered"

      if [ "$do_homebrew" = "1" ] && command -v brew >/dev/null 2>&1; then
        export HOMEBREW_NO_AUTO_UPDATE=1
        run brew cleanup -s --prune=all
      fi

      if [ "$do_beeper_uploads" = "1" ]; then
        prune_top_level_by_age "$home/Library/Application Support/BeeperTexts/api-uploads" "$transient_days"
      fi

      if [ "$do_bun" = "1" ]; then
        if process_running '(^|/)(bun)( |$).*(install|add|update)'; then
          log "keeping Bun cache while a package operation is active"
        else
          clear_cache_dir "Bun package" "$home/.bun/install/cache" "$bun_max_gib"
        fi
      fi

      if [ "$do_npm" = "1" ]; then
        if process_running '(^|/)(npm|npx)( |$)'; then
          log "keeping npm cache while a package operation is active"
        elif command -v npm >/dev/null 2>&1; then
          if cache_exceeds_limit "$home/.npm/_cacache" "$npm_max_gib"; then
            run npm cache clean --force
          else
            run npm cache verify
          fi
        fi
        prune_top_level_by_age "$home/.npm/_npx" "$npx_days"
      fi

      if [ "$do_pnpm" = "1" ] && command -v pnpm >/dev/null 2>&1; then
        pnpm_roots=(
      ${lib.concatMapStringsSep "\n" (root: "          ${lib.escapeShellArg root}") cfg.pnpm.projectRoots}
        )
        for root in "''${pnpm_roots[@]}"; do
          if [ -d "$root" ]; then
            log "pruning pnpm store selected by $root"
            if (cd "$root" && pnpm store prune); then
              :
            else
              status=$?
              failures=$((failures + 1))
              log "warning: pnpm store prune failed with status=$status in $root"
            fi
          fi
        done
      fi

      if [ "$do_gradle" = "1" ]; then
        if process_running 'GradleDaemon|(^|/)(gradle|gradlew)( |$)'; then
          log "keeping Gradle cache while a build daemon is active"
        else
          clear_cache_dir "Gradle" "$home/.gradle/caches" "$gradle_max_gib"
        fi
      fi

      if [ "$do_xcode" = "1" ]; then
        prune_top_level_by_age "$home/Library/Developer/Xcode/DerivedData" "$derived_data_days"
      fi

      if [ "$do_cocoapods" = "1" ] && command -v pod >/dev/null 2>&1; then
        run pod cache clean --all
      fi

      if [ "$do_user_cache" = "1" ]; then
        prune_cache_files_by_age "$home/.cache" "$user_cache_days"
      fi

      if [ "$do_go_builds" = "1" ]; then
        if process_running '(^|/)(go)( |$).*(build|clean|env|generate|install|run|test|tool)'; then
          log "keeping Go temporary builds while a Go command is active"
        else
          ${lib.optionalString isLinux ''
            prune_named_top_level_by_age "/tmp" "go-build*" ${toString cfg.goBuildRetentionDays}
          ''}
          ${lib.optionalString isDarwin ''
            darwin_tmp=$(/usr/bin/getconf DARWIN_USER_TEMP_DIR 2>/dev/null || true)
            if [ -n "$darwin_tmp" ]; then
              prune_named_top_level_by_age "$darwin_tmp" "go-build*" ${toString cfg.goBuildRetentionDays}
            fi
          ''}
        fi
      fi

      if [ "$do_go_build_cache" = "1" ] && command -v go >/dev/null 2>&1; then
        if process_running '(^|/)(go)( |$).*(build|clean|env|generate|install|run|test|tool)'; then
          log "keeping Go build caches while a Go command is active"
        else
          go_build_caches=()
          default_go_build_cache=$(go env GOCACHE 2>/dev/null || true)
          if [ -n "$default_go_build_cache" ]; then
            go_build_caches+=("$default_go_build_cache")
          fi
          go_build_caches+=(
      ${lib.concatMapStringsSep "\n" (
        dir: "            ${lib.escapeShellArg dir}"
      ) cfg.goBuildCache.extraDirectories}
          )
          for go_build_cache in "''${go_build_caches[@]}"; do
            clean_go_cache "$go_build_cache"
          done
        fi
      fi

      if [ "$do_docker_build" = "1" ] && command -v docker >/dev/null 2>&1; then
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

    transientRetentionDays = lib.mkOption {
      type = lib.types.ints.positive;
      default = 1;
      description = "Delete transient app upload/cache entries older than this many days.";
    };

    npxRetentionDays = lib.mkOption {
      type = lib.types.ints.positive;
      default = 14;
      description = "Delete npx temporary package directories older than this many days.";
    };

    xcodeDerivedDataRetentionDays = lib.mkOption {
      type = lib.types.ints.positive;
      default = 14;
      description = "Delete Xcode DerivedData entries older than this many days.";
    };

    userCacheRetentionDays = lib.mkOption {
      type = lib.types.ints.positive;
      default = 30;
      description = "Delete cache files that have not been accessed or modified for this many days.";
    };

    goBuildRetentionDays = lib.mkOption {
      type = lib.types.ints.positive;
      default = 1;
      description = "Delete abandoned Go build temporary directories older than this many days.";
    };

    homebrew.enable = lib.mkOption {
      type = lib.types.bool;
      default = isDarwin;
      description = "Run Homebrew cleanup for stale downloads and old formula versions.";
    };

    beeperUploads.enable = lib.mkOption {
      type = lib.types.bool;
      default = isDarwin;
      description = "Prune Beeper Desktop API temporary upload files by age.";
    };

    bun.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Cap Bun's reproducible package cache.";
    };

    bun.maxSizeGiB = lib.mkOption {
      type = lib.types.ints.positive;
      default = 6;
      description = "Keep the Bun package cache unless it grows beyond this size.";
    };

    npm.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Verify the npm cache and remove old npx temporary directories.";
    };

    npm.maxSizeGiB = lib.mkOption {
      type = lib.types.ints.positive;
      default = 4;
      description = "Keep the npm content cache unless it grows beyond this size.";
    };

    pnpm.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Run pnpm store prune to remove unreferenced store packages.";
    };

    pnpm.projectRoots = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ homeDir ];
      description = "Project roots used to select and prune each active pnpm store version.";
    };

    gradle.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Cap Gradle's reproducible dependency and transform cache.";
    };

    gradle.maxSizeGiB = lib.mkOption {
      type = lib.types.ints.positive;
      default = 12;
      description = "Keep Gradle caches unless they grow beyond this size.";
    };

    xcodeDerivedData.enable = lib.mkOption {
      type = lib.types.bool;
      default = isDarwin;
      description = "Prune stale Xcode DerivedData.";
    };

    cocoapods.enable = lib.mkOption {
      type = lib.types.bool;
      default = isDarwin;
      description = "Clear the CocoaPods download cache.";
    };

    userCache.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Prune stale files and resulting empty directories in the user cache directory.";
    };

    goBuilds.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Prune abandoned Go build temporary directories.";
    };

    goBuildCache.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Cap Go's reproducible build cache without deleting downloaded modules.";
    };

    goBuildCache.maxSizeGiB = lib.mkOption {
      type = lib.types.ints.positive;
      default = 3;
      description = "Keep the Go build cache unless it grows beyond this size.";
    };

    goBuildCache.extraDirectories = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional reproducible Go build caches managed like the cache reported by `go env GOCACHE`.";
    };

    dockerBuild.enable = lib.mkOption {
      type = lib.types.bool;
      default = isLinux;
      description = "Prune Docker build cache while preserving images and volumes.";
    };

    dockerBuild.maxSizeGiB = lib.mkOption {
      type = lib.types.ints.positive;
      default = 10;
      description = "Maximum Docker build-cache size retained by routine cleanup.";
    };

    dockerBuild.reservedSizeGiB = lib.mkOption {
      type = lib.types.ints.positive;
      default = 2;
      description = "Useful Docker build cache retained even during cleanup.";
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
