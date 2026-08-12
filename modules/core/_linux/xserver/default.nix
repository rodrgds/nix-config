{ lib, config, ... }:
let
  cfg = config.core.xserver;
in
{
  options.core.xserver = {
    enable = lib.mkEnableOption "Enable X Server";
  };

  config = lib.mkIf cfg.enable {
    services.xserver = {
      enable = true;
      xkb.layout = "us";
      xkb.variant = "";
      videoDrivers = [ "nvidia" ];
      desktopManager.xterm.enable = false;
    };
  };
}
