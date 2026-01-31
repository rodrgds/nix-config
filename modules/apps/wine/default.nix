{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.wine;
in
{
  options.apps.wine = {
    enable = lib.mkEnableOption "Enable Wine";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.wine ];
  };
}
