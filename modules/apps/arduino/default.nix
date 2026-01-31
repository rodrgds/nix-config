{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.arduino;
in
{
  options.apps.arduino = {
    enable = lib.mkEnableOption "Enable Arduino IDE";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.arduino-ide ];
  };
}
