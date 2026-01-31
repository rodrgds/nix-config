{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.grayjay;
in
{
  options.apps.grayjay = {
    enable = lib.mkEnableOption "Enable Grayjay";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.grayjay ];
  };
}
