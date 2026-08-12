{
  lib,
  config,
  pkgs,
  constants,
  ...
}:
let
  cfg = config.apps.xdg-portals;
  inherit (constants) isLinux;
in
{
  options.apps.xdg-portals = {
    enable = lib.mkEnableOption "Enable xdg-portals";
  };

  config = lib.mkIf (cfg.enable && isLinux) {
    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
      config = {
        common.default = [ "gtk" ];
        hyprland.default = [
          "hyprland"
          "gtk"
        ];
      };
    };
  };
}
