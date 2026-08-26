{
  lib,
  config,
  pkgs,
  constants,
  ...
}:
let
  cfg = config.apps.brave;
  inherit (constants) isDarwin isLinux;
in
{
  options.apps.brave.enable = lib.mkEnableOption "Enable Brave web browser";

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.brave ];
      })

      (lib.optionalAttrs isDarwin {
        homebrew.casks = [ "brave-browser" ];
      })
    ]
  );
}
