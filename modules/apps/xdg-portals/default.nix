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
}
// lib.optionalAttrs isLinux {

  # xdg.portal is a NixOS-only option, so omit the path before Darwin's
  # module checker sees it rather than wrapping it in a false mkIf.
  config = lib.mkIf cfg.enable {
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
