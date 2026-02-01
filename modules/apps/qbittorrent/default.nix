{
  lib,
  config,
  pkgs,
  username,
  system,
  ...
}:
let
  cfg = config.apps.qbittorrent;
  isLinux = lib.hasSuffix "-linux" system;
in
{
  options.apps.qbittorrent = {
    enable = lib.mkEnableOption "Enable qBittorrent";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.qbittorrent ];
      })
    ]
  );
}
