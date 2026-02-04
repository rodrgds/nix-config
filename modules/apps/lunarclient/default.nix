{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.lunarclient;
  inherit (constants) isLinux;
in
{
  options.apps.lunarclient = {
    enable = lib.mkEnableOption "Enable Lunar Client (Minecraft)";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.lunar-client ];
      })
    ]
  );
}
