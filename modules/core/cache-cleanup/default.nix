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

  cleanupScript = pkgs.writeShellApplication {
    name = "rgo-cache-cleanup";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
    ];
    text = ''
      set -u

      export PATH="/opt/homebrew/bin:/usr/local/bin:${homeDir}/.local/bin:${homeDir}/.nix-profile/bin:/etc/profiles/per-user/${username}/bin:/run/current-system/sw/bin:$PATH"

      home=${lib.escapeShellArg homeDir}
      transient_days=${toString cfg.transientRetentionDays}
      npx_days=${toString cfg.npxRetentionDays}
      do_homebrew=${if cfg.homebrew.enable then "1" else "0"}
      do_beeper_uploads=${if cfg.beeperUploads.enable then "1" else "0"}
      do_bun=${if cfg.bun.enable then "1" else "0"}
      do_npm=${if cfg.npm.enable then "1" else "0"}
      do_pnpm=${if cfg.pnpm.enable then "1" else "0"}

      log() {
        printf '[%s] rgo-cache-cleanup: %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*"
      }

      run() {
        log "running: $*"
        "$@" || log "warning: command failed: $*"
      }

      prune_top_level_by_age() {
        dir=$1
        days=$2
        if [ -d "$dir" ]; then
          log "removing top-level entries in $dir older than $days days"
          find "$dir" -xdev -mindepth 1 -maxdepth 1 -mtime +"$days" -exec rm -rf -- {} + || log "warning: failed to prune $dir"
        fi
      }

      log "started"

      if [ "$do_homebrew" = "1" ] && command -v brew >/dev/null 2>&1; then
        export HOMEBREW_NO_AUTO_UPDATE=1
        run brew cleanup -s --prune=all
      fi

      if [ "$do_beeper_uploads" = "1" ]; then
        prune_top_level_by_age "$home/Library/Application Support/BeeperTexts/api-uploads" "$transient_days"
      fi

      if [ "$do_bun" = "1" ] && command -v bun >/dev/null 2>&1; then
        run bun pm cache rm
      fi

      if [ "$do_npm" = "1" ]; then
        if command -v npm >/dev/null 2>&1; then
          run npm cache verify
        fi
        prune_top_level_by_age "$home/.npm/_npx" "$npx_days"
      fi

      if [ "$do_pnpm" = "1" ] && command -v pnpm >/dev/null 2>&1; then
        run pnpm store prune
      fi

      log "finished"
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
      description = "Run bun pm cache rm to clear Bun's package cache.";
    };

    npm.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Verify the npm cache and remove old npx temporary directories.";
    };

    pnpm.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Run pnpm store prune to remove unreferenced store packages.";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isDarwin {
        launchd.agents.cache-cleanup = {
          serviceConfig = {
            ProgramArguments = [ "${cleanupScript}/bin/rgo-cache-cleanup" ];
            StartInterval = cfg.intervalSeconds;
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
