{
  lib,
  config,
  pkgs,
  constants,
  ...
}:
let
  cfg = config.darwin.core.fonts;
in
{
  options.darwin.core.fonts = {
    enable = lib.mkEnableOption "Enable Darwin fonts configuration";
  };

  config = lib.mkIf cfg.enable {
    # Font configuration for macOS
    fonts.packages = with pkgs; [
      # Nerd Fonts
      nerd-fonts.jetbrains-mono
      nerd-fonts.fira-code

      # Other fonts
      bricolage-grotesque
    ];
  };
}
