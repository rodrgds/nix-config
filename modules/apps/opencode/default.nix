{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.opencode;
in
{
  options.apps.opencode = {
    enable = lib.mkEnableOption "Enable Opencode CLI";
  };

  config = lib.mkIf cfg.enable {
    # Install opencode CLI
    environment.systemPackages = [ pkgs.opencode ];

    home-manager.users.${username} =
      { ... }:
      {
        programs.opencode = {
          enable = true;
          skills = {
            nushell = builtins.readFile ./nushell-skill.md;
          };
          settings = {
            theme = "gruvbox";
            autoupdate = true;
            mcp = {
              svelte = {
                type = "local";
                command = [
                  "npx"
                  "-y"
                  "@sveltejs/mcp"
                ];
              };
            };
          };
        };

        home.sessionVariables = {
          OPENCODE_ENABLE_EXA = "1";
        };
      };
  };
}
