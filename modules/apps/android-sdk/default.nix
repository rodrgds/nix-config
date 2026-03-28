{
  lib,
  config,
  pkgs,
  inputs,
  username,
  system,
  constants,
  homeDir,
  ...
}:
let
  cfg = config.apps.android-sdk;
  hostSystem = pkgs.stdenv.hostPlatform.system;
  inherit (constants) isLinux isDarwin;

  androidSdk = inputs.android-nixpkgs.sdk.${hostSystem} (
    sdkPkgs: with sdkPkgs; [
      cmdline-tools-latest
      build-tools-34-0-0
      platform-tools
      platforms-android-34
      emulator
    ]
  );
in
{
  options.apps.android-sdk = {
    enable = lib.mkEnableOption "Enable Android SDK";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [
          androidSdk
          pkgs.android-tools
          pkgs.apksigner
        ];

        environment.sessionVariables = {
          ANDROID_HOME = "${homeDir}/Android/Sdk";
          ANDROID_SDK_ROOT = "${homeDir}/Android/Sdk";
          CAPACITOR_ANDROID_STUDIO_PATH = "${pkgs.android-studio}/bin/android-studio";
          VK_ICD_FILENAMES = "/run/opengl-driver/share/vulkan/icd.d/nvidia_icd.x86_64.json";
          ANDROID_EMULATOR_USE_SYSTEM_LIBS = "1";
          LD_LIBRARY_PATH = "${pkgs.libglvnd}/lib:/run/opengl-driver/lib:/run/opengl-driver-32/lib";
          __GL_THREADED_OPTIMIZATIONS = "0"; # emulator was unusable, not its pretty good
        };

        nixpkgs.config.android_sdk.accept_license = true;
      })
      (lib.optionalAttrs isDarwin {
        homebrew.casks = [ "android-platform-tools" ];

        environment.variables = {
          ANDROID_HOME = "$HOME/Library/Android/sdk";
          ANDROID_SDK_ROOT = "$HOME/Library/Android/sdk";
          CAPACITOR_ANDROID_STUDIO_PATH = "/Applications/Android Studio.app/Contents/MacOS/studio";
        };
      })
    ]
  );
}
