{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.alacritty;
in
{
  options.apps.alacritty = {
    enable = lib.mkEnableOption "Enable Alacritty terminal";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.alacritty ];

    home-manager.users.${username} =
      { ... }:
      {
        programs.alacritty = {
          enable = true;
          settings = {
            font = {
              size = constants.fonts.sizes.large;
              bold = {
                family = constants.fonts.primary;
                style = "Bold";
              };
              bold_italic = {
                family = constants.fonts.primary;
                style = "Bold Italic";
              };
              italic = {
                family = constants.fonts.primary;
                style = "Italic";
              };
              normal = {
                family = constants.fonts.primary;
                style = "Regular";
              };
            };
            window = {
              opacity = constants.display.opacity;
              padding = {
                x = 5;
                y = 5;
              };
            };
            colors = {
              primary = {
                background = constants.colors.bg0;
                foreground = constants.colors.fg0;
              };
              normal = {
                black = constants.colors.bg0;
                red = constants.colors.red;
                green = constants.colors.green;
                yellow = constants.colors.yellow;
                blue = constants.colors.blue;
                magenta = constants.colors.magenta;
                cyan = constants.colors.cyan;
                white = constants.colors.fg1;
              };
              bright = {
                black = constants.colors.fg2;
                red = constants.colors.redBright;
                green = constants.colors.greenBright;
                yellow = constants.colors.yellowBright;
                blue = constants.colors.blueBright;
                magenta = constants.colors.magentaBright;
                cyan = constants.colors.cyanBright;
                white = constants.colors.fg0;
              };
            };
          };
        };
      };
  };
}
