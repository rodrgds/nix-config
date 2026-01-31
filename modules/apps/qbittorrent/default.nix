{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.qbittorrent;
in
{
  options.apps.qbittorrent = {
    enable = lib.mkEnableOption "Enable qBittorrent";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.qbittorrent ];
  };
}
