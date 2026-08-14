{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.darwin.core.karabiner;

  # Karabiner configuration for remapping ± (Section) key to backtick/tilde
  karabinerConfig = {
    global = {
      check_for_updates_on_startup = false;
      show_in_menu_bar = true;
      show_profile_name_in_menu_bar = false;
    };
    profiles = [
      {
        name = "Default";
        selected = true;
        simple_modifications = [ ];
        complex_modifications = {
          rules = [
            {
              description = "Remap ± (§) key to backtick (`) and Shift+± to tilde (~)";
              manipulators = [
                {
                  type = "basic";
                  from = {
                    # "non_us_backslash" is the technical name for the ISO §/± key
                    key_code = "non_us_backslash";
                    modifiers = {
                      optional = [ "any" ];
                    };
                  };
                  to = [
                    {
                      key_code = "grave_accent_and_tilde";
                    }
                  ];
                }
              ];
            }
            {
              description = "Use Command+Space for Vicinae instead of Spotlight";
              manipulators = [
                {
                  type = "basic";
                  from = {
                    key_code = "spacebar";
                    modifiers = {
                      mandatory = [ "command" ];
                    };
                  };
                  to = [
                    {
                      shell_command = "/opt/homebrew/bin/vicinae toggle";
                    }
                  ];
                }
              ];
            }
          ];
        };
        virtual_hid_keyboard = {
          keyboard_type_v2 = "ansi";
        };
      }
    ];
  };
in
{
  options.darwin.core.karabiner = {
    enable = lib.mkEnableOption "Enable Karabiner-Elements";
  };

  config = lib.mkIf cfg.enable {
    homebrew.casks = [ "karabiner-elements" ];

    home-manager.users.${username} = {
      xdg.configFile."karabiner/karabiner.json".text = builtins.toJSON karabinerConfig;
    };
  };
}
