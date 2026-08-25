{ lib, config, ... }:
let
  cfg = config.core.peripherals;
in
{
  options.core.peripherals = {
    enable = lib.mkEnableOption "Enable peripherals";
  };

  config = lib.mkIf cfg.enable {
    hardware.logitech.wireless.enable = true;
    # apps.solaar owns the graphical package and user service.
    hardware.logitech.wireless.enableGraphical = false;
  };
}
