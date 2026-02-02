{
  lib,
  config,
  pkgs,
  username,
  system,
  constants,
  ...
}:
let
  cfg = config.apps.android-studio;
  inherit (constants) isLinux;
in
{
  options.apps.android-studio = {
    enable = lib.mkEnableOption "Enable Android Studio";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.android-studio ];
      })
    ]
  );
}
