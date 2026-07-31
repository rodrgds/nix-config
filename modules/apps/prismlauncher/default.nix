{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.prismlauncher;
  inherit (constants) isLinux;
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
