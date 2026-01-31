{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.xdg-portals;
in
{
  options.apps.xdg-portals = {
    enable = lib.mkEnableOption "Enable XDG Desktop Portals";
  };

  config = lib.mkIf cfg.enable {
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

    home-manager.users.${username} =
      { ... }:
      {
        xdg.configFile."xdg-desktop-portal/portals.conf".text = ''
          [preferred]
          default=gtk
        '';
      };
  };
}
