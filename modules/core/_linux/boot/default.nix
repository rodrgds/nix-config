{ lib, config, ... }:
let
  cfg = config.core.boot;
in
{
  options.core.boot = {
    enable = lib.mkEnableOption "Enable boot";
  };

  config = lib.mkIf cfg.enable {
    boot.loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
      efi.efiSysMountPoint = "/boot";
    };
  };
}
