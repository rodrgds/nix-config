{
  lib,
  config,
  pkgs,
  constants,
  ...
}:
let
  cfg = config.apps.cursor;
  inherit (constants) isDarwin isLinux;
in
{
  options.apps.cursor = {
    enable = lib.mkEnableOption "Enable Cursor";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [
          pkgs.unstable.code-cursor
          pkgs.unstable.cursor-cli
        ];
      })
      (lib.optionalAttrs isDarwin {
        homebrew.casks = [
          "cursor"
          "cursor-cli"
        ];
      })
    ]
  );
}
