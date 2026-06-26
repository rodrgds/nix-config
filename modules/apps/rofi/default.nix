{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.rofi;
in
{
  options.apps.rofi = {
    enable = lib.mkEnableOption "Enable Rofi";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.rofi ];

    home-manager.users.${username} = _: {
      home.file.".config/rofi/config.rasi".text = ''
        * {
          background:     #100F0F;
          foreground:     #CECDC3;
          background-alt: #1C1B1A;
          foreground-alt: #6F6E69;
          selected:       #3AA99F;
          active:         #879A39;
          urgent:         #D14D41;
          border:         #403E3C;
          text:           #CECDC3;
          red:            #D14D41;
          blue:           #4385BE;
          green:          #879A39;
          yellow:         #D0A215;
          magenta:        #CE5D97;
          cyan:           #3AA99F;
          orange:         #DA702C;
        }

        window {
          background-color: @background;
          border: 2px;
          border-color: @border;
          border-radius: 10px;
          padding: 8px;
        }

        mainbox {
          background-color: @background;
          border: 0px;
          padding: 4px;
        }

        inputbar {
          background-color: @background-alt;
          text-color: @foreground;
          border-radius: 8px;
          padding: 6px 12px;
          margin: 0 0 8px 0;
        }

        listview {
          background-color: @background;
          padding: 0;
          margin: 0;
        }

        element {
          background-color: @background;
          text-color: @foreground;
          padding: 6px 12px;
          border-radius: 8px;
        }

        element selected {
          background-color: @selected;
          text-color: @background;
        }

        element-icon {
          background-color: inherit;
          text-color: inherit;
          size: 24px;
        }

        element-text {
          background-color: inherit;
          text-color: inherit;
          vertical-align: 0.5;
        }

        configuration {
          modi: "drun,run,window";
          show-icons: true;
          terminal: "ghostty";
          drun-display-format: "{name}";
          location: 0;
          disable-history: false;
          hide-scrollbar: true;
          display-drun: " Apps ";
          display-run: " Run ";
          display-window: " Window ";
        }
      '';
    };
  };
}
