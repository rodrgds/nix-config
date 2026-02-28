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

    environment.shellAliases = {
      "copy" = "xclip -selection clipboard";
      "v" = "nvim";
      "glog" = "git log --oneline --graph --decorate --all";
      "ll" = "ls -laFh";
      "rescrobbled-logs" = "journalctl --user -u rescrobbled.service -f";
    };
  };
}
