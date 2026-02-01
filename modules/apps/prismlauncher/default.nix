{
  lib,
  config,
  pkgs,
  username,
  system,
  ...
}:
let
  cfg = config.apps.prismlauncher;
  isLinux = lib.hasSuffix "-linux" system;
in
{
  options.apps.prismlauncher = {
    enable = lib.mkEnableOption "Enable Prism Launcher";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.prismlauncher ];
      })
    ]
  );
}
