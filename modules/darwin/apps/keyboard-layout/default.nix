{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.darwin.apps.keyboard-layout;
in
{
  options.darwin.apps.keyboard-layout = {
    enable = lib.mkEnableOption "the Portuguese/US keyboard layout toggle";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = constants.isDarwin;
        message = "darwin.apps.keyboard-layout is only supported on macOS";
      }
    ];

    home-manager.users.${username}.home.packages = [
      (pkgs.writeShellScriptBin "toggle-keyboard-layout" ''
        current="$(${lib.getExe pkgs.macism})"
        case "$current" in
          com.apple.keylayout.Portuguese)
            ${lib.getExe pkgs.macism} com.apple.keylayout.US
            ;;
          *)
            ${lib.getExe pkgs.macism} com.apple.keylayout.Portuguese
            ;;
        esac
        # Refresh the SketchyBar keyboard item when the instrument rail is up.
        if command -v sketchybar >/dev/null 2>&1; then
          sketchybar --trigger keyboard_layout_change
        fi
      '')
    ];
  };
}
