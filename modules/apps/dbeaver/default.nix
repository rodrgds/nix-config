{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.dbeaver;
in
{
  options.apps.dbeaver = {
    enable = lib.mkEnableOption "Enable DBeaver";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.dbeaver-bin ];
  };
}
