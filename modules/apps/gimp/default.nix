{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.gimp;
in
{
  options.apps.gimp = {
    enable = lib.mkEnableOption "Enable GIMP";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.gimp ];
  };
}
