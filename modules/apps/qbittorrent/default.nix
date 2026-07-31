{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.qbittorrent;
  inherit (constants) isLinux isDarwin;
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
      (lib.optionalAttrs isDarwin {
        homebrew.casks = [ "qbittorrent" ];
      })
    ]
  );
}
