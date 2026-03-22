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
  cfg = config.apps.maestro;
  inherit (constants) isDarwin isLinux;
in
{
  options.apps.maestro = {
    enable = lib.mkEnableOption "Enable Maestro mobile automation tool";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.maestro ];
      })
      (lib.optionalAttrs isDarwin {
        homebrew.taps = [ "mobile-dev-inc/tap" ];
        homebrew.brews = [ "mobile-dev-inc/tap/maestro" ];
        homebrew.casks = [ "temurin" ];
      })
    ]
  );
}
