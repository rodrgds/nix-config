{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.charm-freeze;
in
{
  options.apps.charm-freeze = {
    enable = lib.mkEnableOption "Enable Charm Freeze";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.charm-freeze ];
  };
}
