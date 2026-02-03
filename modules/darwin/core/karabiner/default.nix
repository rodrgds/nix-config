{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.darwin.core.karabiner;
  
  # Karabiner configuration for remapping ± key to backtick/tilde
  karabinerConfig = {
    profiles = [
      {
        name = "Default";
        selected = true;
        simple_modifications = [];
        complex_modifications = {
          rules = [
            {
              description = "Remap ± key to backtick (`) and Shift+± to tilde (~)";
              manipulators = [
                {
                  type = "basic";
                  from = {
                    key_code = "non_us_backslash";
                    modifiers = {
                      optional = ["any"];
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
    enable = lib.mkEnableOption "Enable Karabiner-Elements for key remapping";
  };

  config = lib.mkIf cfg.enable {
    # Install Karabiner-Elements via Homebrew
    homebrew.casks = [ "karabiner-elements" ];

    # Create the Karabiner configuration file
    home-manager.users.${username} = {
      home.file."Library/Application Support/Karabiner-Elements/karabiner.json".text = 
        builtins.toJSON karabinerConfig;
    };

    # Ensure Karabiner-Elements is started on login
    system.activationScripts.postActivation.text = lib.mkAfter ''
      # Restart Karabiner-Elements to pick up new configuration
      if pgrep -x "Karabiner-Elements" > /dev/null; then
        echo "Restarting Karabiner-Elements to apply new configuration..."
        killall "Karabiner-Elements" 2>/dev/null || true
        sleep 1
        open -a "Karabiner-Elements"
      fi
    '';
  };
}
