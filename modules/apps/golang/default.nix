{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.apps.golang;
in
{
  options.apps.golang = {
    enable = lib.mkEnableOption "Enable Golang";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.go
    ];
  };
}
