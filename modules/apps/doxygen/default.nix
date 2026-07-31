{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.apps.doxygen;
in
{
  options.apps.doxygen = {
    enable = lib.mkEnableOption "Enable Doxygen";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.doxygen
    ];
  };
}
