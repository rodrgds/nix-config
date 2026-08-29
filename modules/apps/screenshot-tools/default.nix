{
  lib,
  config,
  pkgs,
  constants,
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
        environment.systemPackages = [ pkgs.unstable.satty ];
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
