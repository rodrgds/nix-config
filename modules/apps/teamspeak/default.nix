{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.teamspeak;
in
{
  options.apps.teamspeak = {
    enable = lib.mkEnableOption "Enable TeamSpeak";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.teamspeak6-client ];
  };
}
