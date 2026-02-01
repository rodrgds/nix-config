{
  lib,
  config,
  pkgs,
  username,
  system,
  ...
}:
let
  cfg = config.apps.davinci-resolve;
  isLinux = lib.hasSuffix "-linux" system;
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
