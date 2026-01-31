{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.steam;
in
{
  options.apps.steam = {
    enable = lib.mkEnableOption "Enable Steam";
  };

  config = lib.mkIf cfg.enable {
    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
    };
  };
}
