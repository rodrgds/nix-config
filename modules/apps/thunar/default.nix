{
  lib,
  config,
  pkgs,
  constants,
  ...
}:
let
  cfg = config.apps.thunar;
  inherit (constants) isLinux;
in
{
  options.apps.thunar = {
    enable = lib.mkEnableOption "Enable Thunar";
  };

  config = lib.optionalAttrs isLinux (
    lib.mkIf cfg.enable {
      programs.thunar = {
        enable = true;
        plugins = [ pkgs.thunar-archive-plugin ];
      };

      environment.systemPackages = [
        pkgs.file-roller
        pkgs.tumbler
      ];
    }
  );
}
