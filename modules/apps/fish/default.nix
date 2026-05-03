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
  cfg = config.apps.fish;
  inherit (constants) isDarwin;
in
{
  options.apps.fish = {
    enable = lib.mkEnableOption "Enable Fish shell";
  };

  config = lib.mkIf cfg.enable {
    # Enable fish at system level on NixOS (required for proper PATH setup)
    programs.fish.enable = lib.mkIf (!isDarwin) true;

    # Note: On Darwin, fish is set as default shell in darwin/core/system
    home-manager.users.${username} = {
      programs.fish = {
        enable = true;
        plugins = [
          {
            name = "Gruvbox";
            src = pkgs.fishPlugins.gruvbox;
          }
          {
            name = "fzf";
            src = pkgs.fishPlugins.fzf;
          }
        ];

        # Disable fish greeting
        shellInit = ''
          set -g fish_greeting ""

        ''
        + lib.optionalString isDarwin ''
          # Add Homebrew to PATH on macOS
          if test -d /opt/homebrew/bin
            set -gx PATH /opt/homebrew/bin $PATH
          end

          if test -d /opt/homebrew/sbin
            set -gx PATH /opt/homebrew/sbin $PATH
          end

          # Initialize Homebrew shell environment if available
          if test -f /opt/homebrew/bin/brew
            eval (/opt/homebrew/bin/brew shellenv)
          end
        '';
      };
    };
  };
}
