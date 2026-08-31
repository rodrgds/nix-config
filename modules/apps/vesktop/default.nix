{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.vesktop;
  inherit (constants) isDarwin isLinux;
  flexokiTheme = ''
    /**
     * @name Flexoki Dark
     * @author Rodrigo Dias
     * @description Flexoki's warm ink palette for Vesktop and Vencord.
     * @version 1.0.0
     */

    @import url("https://mwittrien.github.io/BetterDiscordAddons/Themes/DiscordRecolor/DiscordRecolor.css");

    :root {
      --accentcolor: 36, 131, 123;
      --accentcolor2: 206, 93, 151;
      --linkcolor: 58, 169, 159;
      --mentioncolor: 208, 162, 21;
      --successcolor: 135, 154, 57;
      --warningcolor: 208, 162, 21;
      --dangercolor: 209, 77, 65;

      --textbrightest: 218, 216, 206;
      --textbrighter: 206, 205, 195;
      --textbright: 183, 181, 172;
      --textdark: 135, 133, 128;
      --textdarker: 111, 110, 105;
      --textdarkest: 87, 86, 83;

      --backgroundcode: 40, 39, 38;
      --backgroundaccent: 64, 62, 60;
      --backgroundprimary: 16, 15, 15;
      --backgroundsecondary: 28, 27, 26;
      --backgroundsecondaryalt: 28, 27, 26;
      --backgroundtertiary: 16, 15, 15;
      --backgroundfloating: 28, 27, 26;
      --framecolor: 64, 62, 60, 0.55;

      --font: "${constants.fonts.ui}", sans-serif;
      --settingsicons: 0;
    }

    ::selection {
      color: #fffcf0;
      background: #24837b;
    }

    :focus-visible {
      outline-color: #da702c;
    }

    code,
    pre {
      font-family: "${constants.fonts.mono}", monospace !important;
    }
  '';
in
{
  options.apps.vesktop = {
    enable = lib.mkEnableOption "Enable Vesktop";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.vesktop ];
      })
      (lib.optionalAttrs isDarwin {
        homebrew.casks = [ "vesktop" ];
      })
      {
        home-manager.users.${username} = _: {
          programs.vesktop = {
            enable = true;
            package = null;
            settings = {
              splashBackground = constants.colors.bg0;
              splashColor = constants.colors.fg0;
              splashTheming = true;
            };
            vencord = {
              themes.flexoki = flexokiTheme;
              settings = {
                enabledThemes = [ "flexoki.css" ];
                themeLinks = [ ];
                useQuickCss = false;
              };
            };
          };
        };
      }
    ]
  );
}
