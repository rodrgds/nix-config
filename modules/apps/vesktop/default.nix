{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.vesktop;
in
{
  options.apps.vesktop = {
    enable = lib.mkEnableOption "Enable Vesktop";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.vesktop ];
  };
}
