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
    programs.nushell.enable = lib.mkIf (!isDarwin) true;

    home-manager.users.${username} = {
      programs.nushell = {
        enable = true;
        configFile = lib.mkAfter (builtins.toFile "config.nix" ''
          show_banner: false
          use_grid_icons: true
          footer_mode: "25"
          float_precision: 2
          buffer_editor: "vim"
          use_ansi_coloring: true
          bracketed_paste: true
          edit_mode: "vi"
          shell_integration: true
          render_right_prompt_on_last_line: false
        '');
        envConfig = lib.mkAfter (builtins.toFile "env.nix" '');
        extraConfig = ''
          $env.OPENCODE_ENABLE_EXA = "1"
        '' + lib.optionalString isDarwin ''
          if ($"/opt/homebrew/bin/brew --prefix" != "") {
            $env.PATH = ($"/opt/homebrew/bin/brew --prefix/bin") + ($env.PATH | str join)
            $env.PATH = ($"/opt/homebrew/bin/brew --prefix/sbin") + ($env.PATH | str join)
          }
        '';
      };
    };
  };
}
