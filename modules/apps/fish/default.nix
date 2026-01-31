{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.fish;
in
{
  options.apps.fish = {
    enable = lib.mkEnableOption "Enable Fish shell";
  };

  config = lib.mkIf cfg.enable {
    programs.fish.enable = true;

    home-manager.users.${username} =
      { ... }:
      {
        programs.fish = {
          enable = true;
          plugins = [
            {
              name = "Gruvbox";
              src = pkgs.fishPlugins.gruvbox;
            }
            {
              name = "fzf";
              src = pkgs.fishPlugins.fzf;
            }
          ];
        };
      };
  };
}
