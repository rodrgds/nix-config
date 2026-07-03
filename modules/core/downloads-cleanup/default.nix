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
in
{
  options.core.downloads-cleanup = {
    enable = lib.mkEnableOption "Enable downloads-cleanup";

    retentionDays = lib.mkOption {
      type = lib.types.ints.positive;
      default = 30;
      description = "Delete Downloads and Trash entries older than this many days.";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isDarwin {
        launchd.agents.cleanup-user-folders = {
          serviceConfig = {
            ProgramArguments = [
              "/bin/sh"
              "-lc"
              ''
                set -eu

                downloads=${lib.escapeShellArg homeDir}/Downloads
                trash=${lib.escapeShellArg homeDir}/.Trash
                days=${toString cfg.retentionDays}

                echo "[$(/bin/date '+%Y-%m-%dT%H:%M:%S%z')] cleanup-user-folders: deleting top-level Downloads and Trash entries older than $days days"

                if [ -d "$downloads" ]; then
                  /usr/bin/find "$downloads" -xdev -mindepth 1 -maxdepth 1 -mtime +"$days" -exec /bin/rm -rf -- {} +
                fi

                if [ -d "$trash" ]; then
                  /usr/bin/find "$trash" -xdev -mindepth 1 -maxdepth 1 -mtime +"$days" -exec /bin/rm -rf -- {} +
                fi
              ''
            ];
            RunAtLoad = true;
            StartCalendarInterval = [
              {
                Hour = 3;
                Minute = 0;
              }
            ];
            StartInterval = 86400;
            StandardOutPath = "/tmp/cleanup-user-folders.log";
            StandardErrorPath = "/tmp/cleanup-user-folders.err";
          };
        };
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
