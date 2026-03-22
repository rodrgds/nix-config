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
  inherit (constants) isLinux isDarwin;
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
          VK_ICD_FILENAMES = "/run/opengl-driver/share/vulkan/icd.d/nvidia_icd.x86_64.json";
          ANDROID_EMULATOR_USE_SYSTEM_LIBS = "1";
          LD_LIBRARY_PATH = "${pkgs.libglvnd}/lib:/run/opengl-driver/lib:/run/opengl-driver-32/lib";
        };

        nixpkgs.config.android_sdk.accept_license = true;
      })
      (lib.optionalAttrs isDarwin {
        homebrew.casks = [ "android-studio" "temurin@21" ];

        environment.variables = {
          ANDROID_HOME = "$HOME/Library/Android/sdk";
          ANDROID_SDK_ROOT = "$HOME/Library/Android/sdk";
          CAPACITOR_ANDROID_STUDIO_PATH = "/Applications/Android Studio.app/Contents/MacOS/studio";
          JAVA_HOME = "/Library/Java/JavaVirtualMachines/temurin-21.jdk/Contents/Home";
        };

      })
    ]
  );
}
