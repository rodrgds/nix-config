{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.davinci-resolve;
in
{
  options.apps.davinci-resolve = {
    enable = lib.mkEnableOption "Enable DaVinci Resolve Studio";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.davinci-resolve-studio ];
  };
}
