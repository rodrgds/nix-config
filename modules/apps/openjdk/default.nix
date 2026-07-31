{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.openjdk;
in
{
  options.apps.openjdk = {
    enable = lib.mkEnableOption "Enable OpenJDK";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.openjdk21 ];
  };
}
