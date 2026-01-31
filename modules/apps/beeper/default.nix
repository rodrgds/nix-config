{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.beeper;
in
{
  options.apps.beeper = {
    enable = lib.mkEnableOption "Enable Beeper";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.beeper ];
  };
}
