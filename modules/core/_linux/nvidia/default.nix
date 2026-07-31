{ lib, config, ... }:
let
  cfg = config.core.nvidia;
in
{
  options.core.nvidia = {
    enable = lib.mkEnableOption "Enable NVIDIA";
  };

  config = lib.mkIf cfg.enable {
    hardware.graphics.enable = true;

    hardware.nvidia = {
      modesetting.enable = true;
      powerManagement.enable = false;
      powerManagement.finegrained = false;
      open = false;
      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.stable;
    };
  };
}
