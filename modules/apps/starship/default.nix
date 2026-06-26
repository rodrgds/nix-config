{
  lib,
  config,
  username,
  ...
}:
let
  cfg = config.apps.starship;
in
{
  options.apps.starship = {
    enable = lib.mkEnableOption "Enable Starship";
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${username} = {
      programs.starship = {
        enable = true;
        enableZshIntegration = true;
        enableBashIntegration = true;
        enableNushellIntegration = true;
        enableFishIntegration = true;
        settings = {
          # Don't block prompt on slow modules
          command_timeout = 500;
          # Performance: don't scan network drives
          scan_timeout = 30;

          # Warm orange → yellow → cream fade prompt
          format = lib.concatStrings [
            "[](color_1)"
            "$os"
            "$username"
            "[](bg:color_2 fg:color_1)"
            "$directory"
            "[](fg:color_2 bg:color_3)"
            "$git_branch"
            "$git_status"
            "[](fg:color_3 bg:color_4)"
            "$c"
            "$cpp"
            "$rust"
            "$golang"
            "$nodejs"
            "$bun"
            "$php"
            "$java"
            "$kotlin"
            "$haskell"
            "$python"
            "[](fg:color_4 bg:color_5)"
            "$docker_context"
            "$conda"
            "$pixi"
            "[](fg:color_5 bg:color_6)"
            "$time"
            "[ ](fg:color_6)"
            "$line_break$character"
          ];

          palette = "warm_fade";

          palettes.warm_fade = {
            color_1 = "#9D4310";
            color_2 = "#BC5215";
            color_3 = "#CB6120";
            color_4 = "#DA702C";
            color_5 = "#D0A215";
            color_6 = "#DFB431";
            color_fg0 = "#FFFCF0";
            color_fg1 = "#CECDC3";
            color_fg_dark = "#100F0F";
            color_green = "#879A39";
            color_purple = "#8B7EC8";
            color_red = "#D14D41";
          };

          os = {
            disabled = false;
            style = "bg:color_1 fg:color_fg0";
            symbols = {
              Windows = "󰍲";
              Ubuntu = "󰕈";
              SUSE = "";
              Raspbian = "󰐿";
              Mint = "󰣭";
              Macos = "󰀵";
              Manjaro = "";
              Linux = "󰌽";
              Gentoo = "󰣨";
              Fedora = "󰣛";
              Alpine = "";
              Amazon = "";
              Android = "";
              AOSC = "";
              Arch = "󰣇";
              Artix = "󰣇";
              EndeavourOS = "";
              CentOS = "";
              Debian = "󰣚";
              Redhat = "󱄛";
              RedHatEnterprise = "󱄛";
              Pop = "";
              NixOS = "";
            };
          };

          username = {
            show_always = true;
            style_user = "bg:color_1 fg:color_fg0";
            style_root = "bg:color_1 fg:color_fg0";
            format = "[ $user ]($style)";
          };

          directory = {
            style = "fg:color_fg0 bg:color_2";
            format = "[ $path ]($style)";
            truncation_length = 3;
            truncation_symbol = "…/";
            substitutions = {
              "Documents" = "󰈙 ";
              "Downloads" = " ";
              "Music" = "󰝚 ";
              "Pictures" = " ";
              "Developer" = "󰲋 ";
            };
          };

          git_branch = {
            symbol = "";
            style = "bg:color_3";
            format = "[[ $symbol $branch ](fg:color_fg_dark bg:color_3)]($style)";
          };

          git_status = {
            style = "bg:color_3";
            format = "[[($all_status$ahead_behind )](fg:color_fg_dark bg:color_3)]($style)";
            disabled = false;
          };

          nodejs = {
            symbol = "";
            style = "bg:color_4";
            format = "[[ $symbol( $version) ](fg:color_fg_dark bg:color_4)]($style)";
          };

          bun = {
            symbol = "🍞";
            style = "bg:color_4";
            format = "[[ $symbol( $version) ](fg:color_fg_dark bg:color_4)]($style)";
          };

          c = {
            symbol = " ";
            style = "bg:color_4";
            format = "[[ $symbol( $version) ](fg:color_fg_dark bg:color_4)]($style)";
          };

          cpp = {
            symbol = " ";
            style = "bg:color_4";
            format = "[[ $symbol( $version) ](fg:color_fg_dark bg:color_4)]($style)";
          };

          rust = {
            symbol = "";
            style = "bg:color_4";
            format = "[[ $symbol( $version) ](fg:color_fg_dark bg:color_4)]($style)";
          };

          golang = {
            symbol = "";
            style = "bg:color_4";
            format = "[[ $symbol( $version) ](fg:color_fg_dark bg:color_4)]($style)";
          };

          php = {
            symbol = "";
            style = "bg:color_4";
            format = "[[ $symbol( $version) ](fg:color_fg_dark bg:color_4)]($style)";
          };

          java = {
            symbol = "";
            style = "bg:color_4";
            format = "[[ $symbol( $version) ](fg:color_fg_dark bg:color_4)]($style)";
          };

          kotlin = {
            symbol = "";
            style = "bg:color_4";
            format = "[[ $symbol( $version) ](fg:color_fg_dark bg:color_4)]($style)";
          };

          haskell = {
            symbol = "";
            style = "bg:color_4";
            format = "[[ $symbol( $version) ](fg:color_fg_dark bg:color_4)]($style)";
          };

          python = {
            symbol = "";
            style = "bg:color_4";
            format = "[[ $symbol( $version) ](fg:color_fg_dark bg:color_4)]($style)";
          };

          docker_context = {
            symbol = "";
            style = "bg:color_5";
            format = "[[ $symbol( $context) ](fg:color_fg_dark bg:color_5)]($style)";
          };

          conda = {
            style = "bg:color_5";
            format = "[[ $symbol( $environment) ](fg:color_fg_dark bg:color_5)]($style)";
          };

          pixi = {
            style = "bg:color_5";
            format = "[[ $symbol( $version)( $environment) ](fg:color_fg_dark bg:color_5)]($style)";
          };

          time = {
            disabled = false;
            time_format = "%R";
            style = "bg:color_6";
            format = "[[  $time ](fg:color_fg_dark bg:color_6)]($style)";
          };

          line_break = {
            disabled = false;
          };

          character = {
            disabled = false;
            success_symbol = "[](bold fg:color_green)";
            error_symbol = "[](bold fg:color_red)";
            vimcmd_symbol = "[](bold fg:color_green)";
            vimcmd_replace_one_symbol = "[](bold fg:color_purple)";
            vimcmd_replace_symbol = "[](bold fg:color_purple)";
            vimcmd_visual_symbol = "[](bold fg:color_4)";
          };
        };
      };
    };
  };
}
