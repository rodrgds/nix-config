{
  lib,
  config,
  pkgs,
  constants,
  ...
}:
let
  cfg = config.apps.android-studio;
  inherit (constants) isLinux isDarwin;
in
{
  options.apps.android-studio = {
    enable = lib.mkEnableOption "Enable Android Studio";

    packageMode = lib.mkOption {
      type = lib.types.enum [
        "managed"
        "frozen"
      ];
      default = "managed";
      description = ''
        "managed" installs Android Studio in the system closure. "frozen" keeps
        a persistent GC root to the already installed build and only installs a
        lightweight wrapper.
      '';
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        core.frozen-packages.packages.android-studio = {
          mode = cfg.packageMode;
          package = pkgs.android-studio;
          command = "android-studio";
          executablePath = "/bin/android-studio";
          rootName = "rgo-android-studio";
        };
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
