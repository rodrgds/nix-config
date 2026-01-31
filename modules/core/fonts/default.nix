{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.core.fonts;
in
{
  options.core.fonts = {
    enable = lib.mkEnableOption "Enable fonts configuration";
  };

  config = lib.mkIf cfg.enable {
    fonts.packages = with pkgs; [
      inter
      jetbrains-mono
      iosevka
      nerd-fonts.jetbrains-mono
      nerd-fonts.iosevka
      font-awesome
      powerline-fonts
      corefonts
      vista-fonts
      source-serif
      bangers
      bricolage-grotesque
    ];
  };
}
