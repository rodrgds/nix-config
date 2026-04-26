{ lib, config, ... }:
let
  cfg = config.core.audio;
in
{
  options.core.audio = {
    enable = lib.mkEnableOption "Enable audio configuration";
  };

  config = lib.mkIf cfg.enable {
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
  };
}
