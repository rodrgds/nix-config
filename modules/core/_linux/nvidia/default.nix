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
      powerManagement.enable = true;
      powerManagement.finegrained = false;
      # The RTX 2070 (Turing) is supported by NVIDIA's open kernel modules.
      open = true;
      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.stable;
    };
  };
}
