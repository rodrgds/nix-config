{
  lib,
  config,
  pkgs,
  username,
  system,
  ...
}:
let
  cfg = config.apps.arduino;
  isLinux = lib.hasSuffix "-linux" system;
in
{
  options.apps.arduino = {
    enable = lib.mkEnableOption "Enable Arduino IDE";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.arduino-ide ];
      })
    ]
  );
}
