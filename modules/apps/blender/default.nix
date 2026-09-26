{
  lib,
  config,
  pkgs,
  constants,
  ...
}:
let
  cfg = config.apps.blender;
  inherit (constants) isDarwin isLinux;
in
{
  options.apps.blender.enable = lib.mkEnableOption "Enable Blender";

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.blender ];
      })
      (lib.optionalAttrs isDarwin {
        homebrew.casks = [ "blender" ];
      })
    ]
  );
}
