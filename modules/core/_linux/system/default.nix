{ lib, config, ... }:
let
  cfg = config.core.system;
in
{
  options.core.system = {
    enable = lib.mkEnableOption "Enable system configuration";
  };

  config = lib.mkIf cfg.enable {
    system.autoUpgrade = {
      enable = true;
      dates = "weekly";
      flake = "/home/rgo/.config/home";
    };

    system.stateVersion = lib.mkDefault "25.05";
  };
}
