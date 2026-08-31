{
  lib,
  config,
  pkgs,
  username,
  constants,
  system,
  ...
}:
let
  cfg = config.apps.ghostty;
  inherit (constants) isDarwin isLinux;
  ghosttySettings = {
    theme = "Flexoki Dark";
    font-family = constants.fonts.mono;
    font-size = constants.fonts.sizes.large;
    background-opacity = constants.display.opacity;
    window-padding-x = 5;
    window-padding-y = 5;
    shell-integration = "detect";
    shell-integration-features = "cursor,sudo,title";
    clipboard-paste-protection = false;
    confirm-close-surface = false;
    keybind = lib.optionals isDarwin [ "performable:super+v=paste_from_clipboard" ];
  };
in
{
  options.apps.ghostty = {
    enable = lib.mkEnableOption "Enable Ghostty";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      # Linux: Install via nixpkgs and configure via home-manager
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [
          pkgs.ghostty
          pkgs.xdg-terminal-exec
        ];

        home-manager.users.${username} = _: {
          programs.ghostty = {
            enable = true;
            settings = ghosttySettings // {
              window-decoration = false;
            };
          };

          # Use the XDG terminal selector as the single default, then bridge
          # Xfce's legacy preferred-application API to it for Thunar actions.
          xdg.configFile = {
            "xdg-terminals.list".text = "com.mitchellh.ghostty.desktop\n";
            "xfce4/helpers.rc".text = "TerminalEmulator=${lib.getExe pkgs.xdg-terminal-exec}\n";
          };
        };
      })
      # Darwin: Install via Homebrew and configure via home-manager (with package = null)
      (lib.optionalAttrs isDarwin {
        homebrew.casks = [ "ghostty" ];

        home-manager.users.${username} = _: {
          programs.ghostty = {
            enable = true;
            package = null;
            settings = ghosttySettings // {
              # Keep the native frame so macOS clips the window to its rounded
              # corners, while hiding the title bar and traffic lights.
              window-decoration = "auto";
              macos-titlebar-style = "hidden";
            };
          };
        };
      })
    ]
  );
}
