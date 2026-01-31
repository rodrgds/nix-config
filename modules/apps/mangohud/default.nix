{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.mangohud;
in
{
  options.apps.mangohud = {
    enable = lib.mkEnableOption "Enable MangoHud";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.mangohud ];
  };
}
