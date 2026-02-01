{
  lib,
  config,
  pkgs,
  username,
  system,
  ...
}:
let
  cfg = config.apps.android-studio;
  isLinux = lib.hasSuffix "-linux" system;
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
