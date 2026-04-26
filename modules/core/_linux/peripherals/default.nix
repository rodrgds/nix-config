{ lib, config, ... }:
let
  cfg = config.core.peripherals;
in
{
  options.core.peripherals = {
    enable = lib.mkEnableOption "Enable peripherals configuration";
  };

  config = lib.mkIf cfg.enable {
    hardware.logitech.wireless.enable = true;
    hardware.logitech.wireless.enableGraphical = true;
  };
}
