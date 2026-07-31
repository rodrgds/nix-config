{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.bun;
in
{
  options.apps.bun = {
    enable = lib.mkEnableOption "Enable Bun";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.bun ];
  };
}
