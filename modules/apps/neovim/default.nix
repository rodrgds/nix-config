{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.neovim;
in
{
  options.apps.neovim = {
    enable = lib.mkEnableOption "Enable Neovim";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.neovim ];

    home-manager.users.${username} = _: {
      home.sessionVariables = {
        EDITOR = "nvim";
      };
    };
  };
}
