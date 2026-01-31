{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.flameshot;
in
{
  options.apps.flameshot = {
    enable = lib.mkEnableOption "Enable Flameshot";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.flameshot ];
  };
}
