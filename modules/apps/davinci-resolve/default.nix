{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.davinci-resolve;
  inherit (constants) isLinux;
in
{
  options.apps.davinci-resolve = {
    enable = lib.mkEnableOption "Enable DaVinci Resolve Studio";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.davinci-resolve-studio ];
      })
    ]
  );
}
