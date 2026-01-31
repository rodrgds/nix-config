{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.prismlauncher;
in
{
  options.apps.prismlauncher = {
    enable = lib.mkEnableOption "Enable Prism Launcher";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.prismlauncher ];
  };
}
