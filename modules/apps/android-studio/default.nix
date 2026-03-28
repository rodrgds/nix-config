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
      })
      (lib.optionalAttrs isDarwin {
        homebrew.casks = [
          "android-studio"
          "temurin@21"
        ];

        environment.variables = {
          JAVA_HOME = "/Library/Java/JavaVirtualMachines/temurin-21.jdk/Contents/Home";
        };
      })
    ]
  );
}
