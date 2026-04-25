{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.obs;
in
{
  options.apps.obs = {
    enable = lib.mkEnableOption "Enable OBS Studio";
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${username} = _: {
      programs.obs-studio = {
        enable = true;
        package = pkgs.obs-studio.override {
          cudaSupport = true;
        };
        plugins = with pkgs.obs-studio-plugins; [
          obs-vkcapture
          obs-pipewire-audio-capture
          obs-move-transition
          input-overlay
          obs-shaderfilter
          obs-backgroundremoval
          obs-3d-effect
          obs-scale-to-sound
          obs-composite-blur
          obs-gradient-source
          obs-retro-effects
          waveform
        ];
      };
    };
  };
}
