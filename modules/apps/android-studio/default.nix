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
  hostSystem = pkgs.stdenv.hostPlatform.system;
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

        environment.sessionVariables = {
          ANDROID_HOME = "$HOME/Android/Sdk";
          ANDROID_SDK_ROOT = "$HOME/Android/Sdk";
          CAPACITOR_ANDROID_STUDIO_PATH = "${pkgs.android-studio}/bin/android-studio";
        };

        nixpkgs.config.android_sdk.accept_license = true;
      })
    ]
  );
}
