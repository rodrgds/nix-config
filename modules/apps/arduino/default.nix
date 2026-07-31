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
  cfg = config.apps.arduino;
  inherit (constants) isLinux;
in
{
  options.apps.arduino = {
    enable = lib.mkEnableOption "Enable Arduino";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.arduino-ide ];
      })
    ]
  );
}
