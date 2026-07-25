{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.core.downloads-cleanup;
  inherit (constants) isDarwin isLinux homeDir;
  retention = "${toString cfg.retentionDays}d";
  logDir = "${homeDir}/Library/Logs/rgo-maintenance";

  darwinCleanupScript = pkgs.writeShellApplication {
    name = "rgo-cleanup-user-folders";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      mode="''${1:---dry-run}"
      days=${toString cfg.retentionDays}
      log_dir=${lib.escapeShellArg logDir}
      log_file="$log_dir/downloads-cleanup.log"

      mkdir -p "$log_dir"
      exec >>"$log_file" 2>&1

      log() {
        printf '[%s] cleanup-user-folders: %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*"
      }

      if [ "$mode" != "--apply" ] && [ "$mode" != "--dry-run" ]; then
        log "invalid mode: $mode"
        exit 2
      fi

      log "started mode=$mode retention_days=$days"

      if result=$(/usr/bin/osascript - "$days" "$mode" <<'APPLESCRIPT'
      on run argv
        set retentionDays to (item 1 of argv) as integer
        set cleanupMode to item 2 of argv
        set cutoffDate to (current date) - (retentionDays * days)
        set eligibleCount to 0
        set movedCount to 0
        set failedCount to 0

        with timeout of 3600 seconds
          tell application "Finder"
            set downloadsFolder to path to downloads folder
            set candidates to every item of folder downloadsFolder whose modification date is less than cutoffDate
            set eligibleCount to count of candidates

            if cleanupMode is "--apply" then
              repeat with candidateItem in candidates
                try
                  delete candidateItem
                  set movedCount to movedCount + 1
                on error
                  set failedCount to failedCount + 1
                end try
              end repeat
            end if
          end tell
        end timeout

        return "eligible=" & eligibleCount & " moved=" & movedCount & " failed=" & failedCount
      end run
      APPLESCRIPT
      ); then
        log "$result"
      else
        status=$?
        log "Finder cleanup failed with status=$status"
        exit "$status"
      fi

      case "$result" in
        *"failed=0")
          log "finished"
          ;;
        *)
          log "finished with failed items"
          exit 1
          ;;
      esac
    '';
  };
in
{
  options.core.downloads-cleanup = {
    enable = lib.mkEnableOption "Enable downloads-cleanup";

    retentionDays = lib.mkOption {
      type = lib.types.ints.positive;
      default = 30;
      description = "Move Downloads entries older than this many days to Trash.";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isDarwin {
        launchd.agents.cleanup-user-folders = {
          serviceConfig = {
            ProgramArguments = [
              "${darwinCleanupScript}/bin/rgo-cleanup-user-folders"
              "--apply"
            ];
            StartCalendarInterval = [
              {
                Hour = 3;
                Minute = 0;
              }
            ];
            StandardOutPath = "/tmp/cleanup-user-folders.log";
            StandardErrorPath = "/tmp/cleanup-user-folders.err";
          };
        };

        system.defaults.finder.FXRemoveOldTrashItems = true;
      })

      {
        home-manager.users.${username} =
          _:
          lib.mkIf isLinux {
            xdg.configFile."user-tmpfiles.d/rgo-cleanup.conf".text = ''
              d ${homeDir}/Downloads 0755 - - ${retention} -
              d ${homeDir}/.local/share/Trash/files 0700 - - ${retention} -
              d ${homeDir}/.local/share/Trash/info 0700 - - ${retention} -
            '';

            systemd.user.services.rgo-tmpfiles-clean = {
              Unit = {
                Description = "Clean Downloads and Trash with user tmpfiles rules";
              };
              Service = {
                Type = "oneshot";
                ExecStart = "${pkgs.systemd}/bin/systemd-tmpfiles --user --create --clean";
              };
            };

            systemd.user.timers.rgo-tmpfiles-clean = {
              Unit = {
                Description = "Run user tmpfiles cleanup for Downloads and Trash";
              };
              Timer = {
                OnBootSec = "10m";
                OnUnitActiveSec = "1d";
                RandomizedDelaySec = "1h";
                Persistent = true;
                Unit = "rgo-tmpfiles-clean.service";
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
