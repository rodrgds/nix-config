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
      home.shell.enableNushellIntegration = true;

      programs.nushell = {
        enable = true;
        settings = {
          show_banner = false;
          float_precision = 2;
          buffer_editor = "neovim";
          use_ansi_coloring = true;
          bracketed_paste = true;
          edit_mode = "vi";
        };
        environmentVariables = {
          OPENCODE_ENABLE_EXA = "1";
        };
        extraConfig = ''
          mkdir ($nu.data-dir | path join "vendor/autoload")
          starship init nu | save -f ($nu.data-dir | path join "vendor/autoload/starship.nu")
        ''
        + lib.optionalString isDarwin ''
          # Add Homebrew to PATH on macOS
          $env.PATH = ($env.PATH | split row ":" | prepend ["/opt/homebrew/bin" "/opt/homebrew/sbin"] | uniq)
        '';
      };
    };
  };
}
