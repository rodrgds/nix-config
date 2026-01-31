{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.stremio;
in
{
  options.apps.stremio = {
    enable = lib.mkEnableOption "Enable Stremio";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.stremio ];
  };
}
