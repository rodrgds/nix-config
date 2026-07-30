{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.gamemode;
  inherit (constants) isLinux;
in
{
  options.apps.gamemode = {
    enable = lib.mkEnableOption "Enable Gamemode";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        programs.gamemode = {
          enable = true;
          settings = {
            general = {
              desiredgov = "performance";
              renice = 10;
              ioprio = 0;
              disable_splitlock = 1;
              # i3 does not expose org.freedesktop.ScreenSaver, so attempting
              # to inhibit it only creates a D-Bus error on every launch.
              inhibit_screensaver = 0;
            };
            gpu = {
              apply_gpu_optimisations = "accept-responsibility";
              # The RTX 2070 is /sys/class/drm/card1 on rgo-desktop.
              gpu_device = 1;
              nv_powermizer_mode = 1;
            };
          };
        };

        users.users.${username}.extraGroups = [ "gamemode" ];

        # Upstream's helper policy defaults to "no" even for an active local
        # session. Authorize only this configured user and only GameMode's
        # narrowly scoped CPU/GPU/proc helpers.
        security.polkit.extraConfig = ''
          polkit.addRule(function(action, subject) {
            if (subject.user == "${username}" &&
                action.id.indexOf("com.feralinteractive.GameMode.") == 0) {
              return polkit.Result.YES;
            }
          });
        '';
      })
    ]
  );
}
