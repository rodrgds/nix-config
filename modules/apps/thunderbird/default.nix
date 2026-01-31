{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.thunderbird;
in
{
  options.apps.thunderbird = {
    enable = lib.mkEnableOption "Enable Thunderbird";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.thunderbird ];
  };
}
