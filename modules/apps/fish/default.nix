{
  lib,
  config,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.fish;
  inherit (constants) isDarwin;
in
{
  options.apps.fish = {
    enable = lib.mkEnableOption "Enable Fish";
  };

  config = lib.mkIf cfg.enable {
    programs.fish.enable = lib.mkIf (!isDarwin) true;

    home-manager.users.${username} = {
      programs.fish = {
        enable = true;

        shellInit = ''
          set -g fish_greeting ""
        '';

        # Homebrew is only needed for login setup; running it for every Fish
        # process makes interactive and scripted shells unnecessarily slow.
        loginShellInit = lib.optionalString isDarwin ''
          if test -d /opt/homebrew/bin
            set -gx PATH /opt/homebrew/bin $PATH
          end
          if test -d /opt/homebrew/sbin
            set -gx PATH /opt/homebrew/sbin $PATH
          end
          if test -f /opt/homebrew/bin/brew
            eval (/opt/homebrew/bin/brew shellenv)
          end
        '';
      };

      programs.fzf = {
        enable = true;
        enableFishIntegration = true;
      };
      programs.zoxide = {
        enable = true;
        enableFishIntegration = true;
      };
    };
  };
}
