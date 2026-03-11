{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.core.environment;
in
{
  options.core.environment = {
    enable = lib.mkEnableOption "Enable environment configuration";
  };

  config = lib.mkIf cfg.enable {
    environment.pathsToLink = [ "/libexec" ];

    environment.sessionVariables = {
      ANDROID_HOME = "$HOME/.android/sdk";
      ANDROID_SDK_ROOT = "$HOME/.android/sdk";
    };
  };
}
