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
    enable = lib.mkEnableOption "Enable Maestro";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.maestro ];
      })
      (lib.optionalAttrs isDarwin {
        homebrew.taps = [
          {
            name = "mobile-dev-inc/tap";
            trusted = true;
          }
        ];
        homebrew.brews = [ "mobile-dev-inc/tap/maestro" ];
      })
    ]
  );
}
