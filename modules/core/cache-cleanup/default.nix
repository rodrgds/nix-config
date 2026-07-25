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
    ];
    text = ''
      export PATH="/opt/homebrew/bin:/usr/local/bin:${homeDir}/.local/bin:${homeDir}/.nix-profile/bin:/etc/profiles/per-user/${username}/bin:/run/current-system/sw/bin:$PATH"
      export LANG="en_US.UTF-8"

      force=0
      if [ "''${1:-}" = "--force" ]; then
        force=1
      elif [ -n "''${1:-}" ]; then
        printf 'usage: rgo-cache-cleanup [--force]\n' >&2
        exit 2
      fi

      home=${lib.escapeShellArg homeDir}
      interval_seconds=${toString cfg.intervalSeconds}
      transient_days=${toString cfg.transientRetentionDays}
      npx_days=${toString cfg.npxRetentionDays}
      package_cache_days=${toString cfg.packageCacheRetentionDays}
      derived_data_days=${toString cfg.xcodeDerivedDataRetentionDays}
      user_cache_days=${toString cfg.userCacheRetentionDays}
      go_build_days=${toString cfg.goBuildRetentionDays}
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

      prune_top_level_by_age() {
        dir=$1
        days=$2
        if [ -d "$dir" ]; then
          log "removing top-level entries in $dir older than $days days"
          run find "$dir" -xdev -mindepth 1 -maxdepth 1 -mtime +"$days" -exec rm -rf -- {} +
        fi
      }

      prune_named_top_level_by_age() {
        dir=$1
        pattern=$2
        days=$3
        if [ -d "$dir" ]; then
          log "removing $pattern entries in $dir older than $days days"
          run find "$dir" -xdev -mindepth 1 -maxdepth 1 -type d -name "$pattern" -mtime +"$days" -exec rm -rf -- {} +
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

      log "started force=$force"

      if [ "$do_homebrew" = "1" ] && command -v brew >/dev/null 2>&1; then
        export HOMEBREW_NO_AUTO_UPDATE=1
        run brew cleanup -s --prune=all
      fi

      if [ "$do_beeper_uploads" = "1" ]; then
        prune_top_level_by_age "$home/Library/Application Support/BeeperTexts/api-uploads" "$transient_days"
      fi

      if [ "$do_bun" = "1" ] && command -v bun >/dev/null 2>&1; then
        prune_top_level_by_age "$home/.bun/install/cache" "$package_cache_days"
      fi

      if [ "$do_npm" = "1" ]; then
        if command -v npm >/dev/null 2>&1; then
          run npm cache clean --force
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
        prune_top_level_by_age "$home/.gradle/caches" "$package_cache_days"
      fi

      if [ "$do_xcode" = "1" ]; then
        prune_top_level_by_age "$home/Library/Developer/Xcode/DerivedData" "$derived_data_days"
      fi

      if [ "$do_cocoapods" = "1" ] && command -v pod >/dev/null 2>&1; then
        run pod cache clean --all
      fi

      if [ "$do_user_cache" = "1" ]; then
        prune_top_level_by_age "$home/.cache" "$user_cache_days"
      fi

      if [ "$do_go_builds" = "1" ]; then
        ${lib.optionalString isDarwin ''
          darwin_tmp=$(/usr/bin/getconf DARWIN_USER_TEMP_DIR 2>/dev/null || true)
          if [ -n "$darwin_tmp" ]; then
            prune_named_top_level_by_age "$darwin_tmp" "go-build*" "$go_build_days"
          fi
        ''}
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

    packageCacheRetentionDays = lib.mkOption {
      type = lib.types.ints.positive;
      default = 30;
      description = "Delete stale Bun and Gradle cache entries older than this many days.";
    };

    xcodeDerivedDataRetentionDays = lib.mkOption {
      type = lib.types.ints.positive;
      default = 14;
      description = "Delete Xcode DerivedData entries older than this many days.";
    };

    userCacheRetentionDays = lib.mkOption {
      type = lib.types.ints.positive;
      default = 30;
      description = "Delete top-level entries in the user cache directory older than this many days.";
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
      description = "Prune stale entries from Bun's package cache.";
    };

    npm.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Clear the npm cache and remove old npx temporary directories.";
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
      description = "Prune stale Gradle cache trees.";
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
      description = "Prune stale top-level entries in the user cache directory.";
    };

    goBuilds.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Prune abandoned Go build temporary directories.";
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
                OnUnitActiveSec = "${toString cfg.intervalSeconds}s";
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
