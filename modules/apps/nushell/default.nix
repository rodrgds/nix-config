{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.nushell;
  inherit (constants) isDarwin;
in
{
  options.apps.nushell = {
    enable = lib.mkEnableOption "Enable Nushell shell";
  };

  config = lib.mkIf cfg.enable {
    # Enable nushell at system level on NixOS (required for proper PATH setup)
    programs.nushell.enable = lib.mkIf (!isDarwin) true;

    # Note: On Darwin, nushell is set as default shell in darwin/core/system
    home-manager.users.${username} = {
      programs.nushell = {
        enable = true;
        configFile = lib.mkAfter (builtins.toFile "config.nix" (lib.generators.toShellKeyValue {} {
          show_banner = false;
          color_config = {
            separator = "#a89984";
            leading_trailing_space_bg = { attr = "green"; };
            header = "#d79921";
            empty = "#928374";
            bool = "#fabd2f";
            int = "#b8bb26";
            filesize = "#fabd2f";
            duration = "#fabd2f";
            float = "#fabd2f";
            string = "#ebdbb2";
            nothing = "#928374";
            binary = "#fabd2f";
            cell-path = "#ebdbb2";
            row_index = "#d79921";
            record = "#ebdbb2";
            list = "#ebdbb2";
            block = "#ebdbb2";
            hints = "#928374";
            search_result = { bg = "red"; fg = "white"; };
            reinstallation = "#cc241d";
            shape_and = "#b16286";
            shape_binary = "#b16286";
            shape_block = "#458588";
            shape_bool = "#98971a";
            shape_closure = "#98971a";
            shape_custom = "#fabd2f";
            shape_datetime = "#689d6a";
            shape_directory = "#689d6a";
            shape_external = "#689d6a";
            shape_externalarg = "#b8bb26";
            shape_filepath = "#689d6a";
            shape_flag = "#b16286";
            shape_float = "#689d6a";
            shape_garbage = { fg = "white"; bg = "red"; attr = "b"; };
            shape_globpattern = "#689d6a";
            shape_int = "#98971a";
            shape_internalcall = "#689d6a";
            shape_list = "#689d6a";
            shape_literal = "#458588";
            shape_match_pattern = "#fabd2f";
            shape_matching_brackets = { attr = "u"; };
            shape_nothing = "#458588";
            shape_operator = "#d79921";
            shape_or = "#b16286";
            shape_pipe = "#b16286";
            shape_precision = "#98971a";
            shape_range = "#d79921";
            shape_record = "#689d6a";
            shape_redirection = "#b16286";
            shape_signature = "#98971a";
            shape_string = "#98971a";
            shape_string_interpolation = "#689d6a";
            shape_table = "#458588";
            shape_variable = "#d65d0e";
            shape_vardecl = "#d65d0e";
          };
          use_grid_icons = true;
          footer_mode = "25";
          float_precision = 2;
          buffer_editor = "vim";
          use_ansi_coloring = true;
          bracketed_paste = true;
          edit_mode = "vi";
          shell_integration = true;
          render_right_prompt_on_last_line = false;
          hooks = {
            pre_prompt = [{ code = "" }];
            pre_execution = [{ code = "" }];
            env_change = {
              GOPATH = [{ code = "" }];
            };
            display_output = "if (term size).columns >= 100 { table -e } else { table }";
            command_not_found = { code = "" };
          };
          menus = [
            {
              name = "completion_menu";
              only_buffer_difference = false;
              marker = "| ";
              type = {
                layout = "columnar";
                columns = 4;
                col_width = 20;
                col_padding = 2;
              }
              style = { text = "green"; selected_text = "green_reverse"; description_text = "yellow"; };
            }
            {
              name = "history_menu";
              only_buffer_difference = true;
              marker = "? ";
              type = {
                layout = "list";
                page_size = 10;
              };
              style = { text = "green"; selected_text = "green_reverse"; description_text = "yellow"; };
            }
            {
              name = "help_menu";
              only_buffer_difference = true;
              marker = "? ";
              type = {
                layout = "description";
                columns = 4;
                col_width = 20;
                col_padding = 2;
                selection_rows = 4;
                description_rows = 10;
              };
              style = { text = "green"; selected_text = "green_reverse"; description_text = "yellow"; };
            }
          ];
          keybindings = [
            {
              name = "completion_menu";
              modifier = "none";
              keycode = "tab";
              mode = ["emacs" "vi_insert" "vi_normal"];
              event = {
                until = [
                  { send = "menu"; name = "completion_menu"; }
                  { send = "menunext"; }
                ];
              };
            }
            {
              modifier = "control";
              keycode = "c";
              mode = ["emacs" "vi_insert" "vi_normal"];
              event = { send = "ctrlc"; };
            }
            {
              modifier = "control";
              keycode = "d";
              mode = ["emacs" "vi_insert" "vi_normal"];
              event = { send = "ctrld"; };
            }
            {
              modifier = "control";
              keycode = "q";
              mode = ["emacs" "vi_insert" "vi_normal"];
              event = { send = "ctrlq"; };
            }
            {
              modifier = "control";
              keycode = "z";
              mode = ["emacs" "vi_insert" "vi_normal"];
              event = { send = "ctrlz"; };
            }
            {
              modifier = "none";
              keycode = "f11";
              mode = ["emacs" "vi_insert" "vi_normal"];
              event = { send = "f11"; };
            }
            {
              modifier = "none";
              keycode = "f12";
              mode = ["emacs" "vi_insert" "vi_normal"];
              event = { send = "f12"; };
            }
          ];
        }));
        envConfig = lib.mkAfter (builtins.toFile "env.nix" (lib.generators.toShellKeyValue {} {
          ENV_VAR = "";
        }));
        extraConfig = ''
          $env.OPENCODE_ENABLE_EXA = "1"
        '' + lib.optionalString isDarwin ''
          # Add Homebrew to PATH on macOS
          if ($"(/opt/homebrew/bin/brew --prefix 2>/dev/null)" != "") {
            $env.PATH = ($"(/opt/homebrew/bin/brew --prefix)/bin") + ($env.PATH | str join)
            $env.PATH = ($"(/opt/homebrew/bin/brew --prefix)/sbin") + ($env.PATH | str join)
          }
        '';
      };
    };
  };
}
