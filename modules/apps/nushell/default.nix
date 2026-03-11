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
    home-manager.users.${username} = {
      programs.nushell = {
        enable = true;
        settings = {
          show_banner = false;
          use_grid_icons = true;
          float_precision = 2;
          buffer_editor = "neovim";
          use_ansi_coloring = true;
          bracketed_paste = true;
          edit_mode = "vi";
          shell_integration = true;
        };
        environmentVariables = {
          OPENCODE_ENABLE_EXA = "1";
        }
        // lib.optionalAttrs isDarwin {
          PATH_EXTRA = "/opt/homebrew/bin:/opt/homebrew/sbin";
        };
      };
    };
  };
}
