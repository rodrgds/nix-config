{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.dunst;
  inherit (constants) isLinux;
in
{
  options.apps.dunst = {
    enable = lib.mkEnableOption "Enable Dunst";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.dunst ];
        services.dbus.packages = [ pkgs.dunst ];
      })

      {
        home-manager.users.${username} = _: {
          services.dunst = lib.mkIf isLinux {
            enable = true;
            settings = {
              global = {
                monitor = 0;
                follow = "mouse";
                width = 300;
                height = 300;
                origin = "top-right";
                offset = "8x56";
                scale = 0;
                notification_limit = 20;
                progress_bar = true;
                progress_bar_height = 6;
                progress_bar_frame_width = 1;
                progress_bar_min_width = 150;
                progress_bar_max_width = 300;
                indicate_hidden = "yes";
                shrink = "no";
                separator_height = 2;
                padding = 8;
                horizontal_padding = 8;
                text_icon_padding = 0;
                frame_width = 2;
                frame_color = "#403E3C";
                separator_color = "frame";
                sort = "yes";
                idle_threshold = 120;
                font = "${constants.fonts.ui} ${toString constants.fonts.sizes.normal}";
                line_height = 0;
                markup = "full";
                format = "<b>%s</b>\\n%b";
                alignment = "left";
                vertical_alignment = "center";
                show_age_threshold = 60;
                word_wrap = "yes";
                ellipsize = "middle";
                ignore_newline = "no";
                stack_duplicates = true;
                hide_duplicate_count = false;
                show_indicators = "yes";
                icon_position = "left";
                min_icon_size = 32;
                max_icon_size = 64;
                icon_path = "/usr/share/icons/Papirus/32x32/status/:/usr/share/icons/Papirus/32x32/devices/";
                sticky_history = "yes";
                history_length = 20;
                browser = "${pkgs.xdg-utils}/bin/xdg-open";
                always_run_script = true;
                title = "Dunst";
                class = "Dunst";
                corner_radius = 10;
                ignore_dbusclose = false;
                force_xwayland = false;
                force_xinerama = false;
                mouse_left_click = "close_current";
                mouse_middle_click = "close_all";
                mouse_right_click = "context";
              };

              experimental = {
                per_monitor_dpi = false;
              };

              urgency_low = {
                background = "#100F0F";
                foreground = "#CECDC3";
                timeout = 10;
                frame_color = "#403E3C";
              };

              urgency_normal = {
                background = "#100F0F";
                foreground = "#CECDC3";
                timeout = 10;
                frame_color = "#BC5215";
              };

              urgency_critical = {
                background = "#100F0F";
                foreground = "#CECDC3";
                timeout = 0;
                frame_color = "#AF3029";
              };

              shortcuts = {
                close = "ctrl+space";
                close_all = "ctrl+shift+space";
                history = "ctrl+grave";
                context = "ctrl+shift+period";
              };
            };
          };
        };
      }
    ]
  );
}
