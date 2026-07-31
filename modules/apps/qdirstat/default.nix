{
  lib,
  config,
  pkgs,
  constants,
  ...
}:
let
  cfg = config.apps.qdirstat;
  inherit (constants) isLinux;
in
{
  options.apps.qdirstat = {
    enable = lib.mkEnableOption "Enable QDirStat";
  };

  config = lib.mkIf (cfg.enable && isLinux) {
    environment.systemPackages = [ pkgs.qdirstat ];
  };
}
