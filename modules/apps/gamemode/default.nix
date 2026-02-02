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
        programs.gamemode.enable = true;
      })
    ]
  );
}
