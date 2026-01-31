{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.winetricks;
in
{
  options.apps.winetricks = {
    enable = lib.mkEnableOption "Enable Winetricks";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.winetricks ];
  };
}
