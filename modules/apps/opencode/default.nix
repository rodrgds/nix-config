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
      { config, ... }:
      {
        programs.opencode = {
          enable = true;
          skills = lib.mapAttrs (name: _: builtins.readFile (./skills + "/${name}")) (
            lib.attrsets.filterAttrs (_: type: type == "regular") (builtins.readDir ./skills)
          );
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
              context7 = {
                type = "remote";
                url = "https://mcp.context7.com/mcp";
                headers = {
                  CONTEXT7_API_KEY = config.sops.placeholder.context7_api_key;
                };
              };
              exa = {
                type = "remote";
                url = "https://mcp.exa.ai/mcp";
                env = {
                  EXA_API_KEY = config.sops.placeholder.exa_api_key;
                };
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
