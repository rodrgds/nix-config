{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.redshift;
  inherit (constants) isLinux;
in
{
  options.apps.redshift = {
    enable = lib.mkEnableOption "Enable Redshift";
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${username} =
      { config, ... }:
      {
        systemd.user.services.redshift = lib.mkIf isLinux {
          Unit = {
            Description = "Redshift color temperature adjuster";
            After = [ "sops-nix.service" ];
            Requires = [ "sops-nix.service" ];
            PartOf = [ "graphical-session.target" ];
            # Hyprland uses hyprsunset; Redshift remains for the i3 fallback.
            ConditionEnvironment = "!WAYLAND_DISPLAY";
          };
          Install = {
            WantedBy = [ "graphical-session.target" ];
          };
          Service = {
            ExecStart = "${pkgs.redshift}/bin/redshift -c ${config.sops.templates."redshift.conf".path}";
            Restart = "on-failure";
            RestartSec = "5s";
          };
        };

        sops.templates."redshift.conf" = lib.mkIf isLinux {
          content = ''
            [redshift]
            location-provider=manual

            [manual]
            lat=${config.sops.placeholder.location_latitude}
            lon=${config.sops.placeholder.location_longitude}
          '';
        };
      };
  };
}
