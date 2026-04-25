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
    enable = lib.mkEnableOption "Enable Rofi (disabled by default)";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.rofi ];

    home-manager.users.${username} = _: {
      home.file.".config/rofi/config.rasi".text = ''
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

        @theme "gruvbox-dark"
      '';
    };
  };
}
