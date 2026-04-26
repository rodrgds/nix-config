{ lib, config, ... }:
let
  cfg = config.core.security;
in
{
  options.core.security = {
    enable = lib.mkEnableOption "Enable security configuration";
  };

  config = lib.mkIf cfg.enable {
    security.polkit.enable = true;
    security.rtkit.enable = true;
  };
}
