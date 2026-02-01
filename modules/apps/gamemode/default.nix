{
  lib,
  config,
  pkgs,
  username,
  system,
  ...
}:
let
  cfg = config.apps.gamemode;
  isLinux = lib.hasSuffix "-linux" system;
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
