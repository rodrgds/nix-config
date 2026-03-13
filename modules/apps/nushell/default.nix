{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.nushell;
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
          buffer_editor = "nvim";
          use_ansi_coloring = true;
          bracketed_paste = true;
          edit_mode = "vi";
        };

        environmentVariables = {
          OPENCODE_ENABLE_EXA = "1";
        };

        extraEnv = lib.optionalString pkgs.stdenv.isDarwin ''
          $env.PATH = (
            $env.PATH
            | default []
            | if ($in | describe) == "string" { split row ":" } else { $in }
            | prepend [
                "/run/current-system/sw/bin"
                "/nix/var/nix/profiles/default/bin"
                ($env.HOME + "/.nix-profile/bin")
                "/etc/profiles/per-user/${username}/bin"
                "/opt/homebrew/bin"
                "/opt/homebrew/sbin"
              ]
            | uniq
          )
        '';
      };
    };
  };
}