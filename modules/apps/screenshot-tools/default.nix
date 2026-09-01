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
          "shottr"
        ];

        # Pika's URL-triggered picker should leave the selected Hex value on
        # the clipboard without requiring a second shortcut.
        system.defaults.CustomUserPreferences."com.superhighfives.Pika" = {
          copyColorOnPick = true;
          hidePikaWhilePicking = true;
          viewedSplash = true;
        };
      })
    ]
  );
}
