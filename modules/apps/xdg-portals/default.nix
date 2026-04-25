{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.xdg-portals;
  inherit (constants) isLinux;
in
{
  options.apps.xdg-portals = {
    enable = lib.mkEnableOption "Enable XDG Desktop Portals";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        xdg.portal = {
          enable = true;
          extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
          config = {
            common.default = [ "gtk" ];
            i3.default = [ "gtk" ];
          };
        };

        systemd.user.services.xdg-desktop-portal-gtk = {
          serviceConfig = {
            Environment = "DISPLAY=:0";
          };
        };
      })

      {
        home-manager.users.${username} = _: {
          xdg.configFile."xdg-desktop-portal/portals.conf".text = ''
            [preferred]
            default=gtk
          '';
        };
      }
    ]
  );
}
