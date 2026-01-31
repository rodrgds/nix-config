{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.gamemode;
in
{
  options.apps.gamemode = {
    enable = lib.mkEnableOption "Enable Gamemode";
  };

  config = lib.mkIf cfg.enable {
    programs.gamemode.enable = true;
  };
}
