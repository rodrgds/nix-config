{
  lib,
  config,
  pkgs,
  constants,
  username,
  ...
}:
let
  cfg = config.apps.screenshot-tools;
  inherit (constants) isLinux isDarwin;
in
{
  options.apps.screenshot-tools = {
    enable = lib.mkEnableOption "Enable screenshot annotation and color-picker tools";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.swappy ];

        # Ctrl+C copies through wl-copy, then closes the editor.
        home-manager.users.${username}.xdg.configFile."swappy/config".text = ''
          [Default]
          early_exit=true
        '';
      })
      (lib.optionalAttrs isDarwin {
        homebrew.casks = [
          "pika"
          "macshot"
        ];

        # Pika's URL-triggered picker should leave the selected Hex value on
        # the clipboard without requiring a second shortcut.
        system.defaults.CustomUserPreferences."com.superhighfives.Pika" = {
          copyColorOnPick = true;
          hidePikaWhilePicking = true;
          viewedSplash = true;
        };

        # AeroSpace owns the global screenshot and OCR shortcuts.
        system.defaults.CustomUserPreferences."com.sw33tlie.macshot.macshot" = lib.genAttrs (map (
          slot: "hotkeyDisabled_${toString slot}"
        ) (lib.range 1 12)) (_: true);

        # Macshot's first URL-triggered capture after login can leave an
        # invisible overlay that blocks later captures. Start it before use.
        home-manager.users.${username}.launchd.agents.macshot = {
          enable = true;
          config = {
            ProgramArguments = [ "/Applications/macshot.app/Contents/MacOS/macshot" ];
            RunAtLoad = true;
            ProcessType = "Interactive";
          };
        };
      })
    ]
  );
}
