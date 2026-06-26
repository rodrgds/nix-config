{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.neovim;

  flexoki-neovim = pkgs.vimUtils.buildVimPluginFrom2Nix {
    pname = "flexoki-neovim";
    version = "main";
    src = pkgs.fetchFromGitHub {
      owner = "kepano";
      repo = "flexoki-neovim";
      rev = "main";
      hash = "sha256-hq0a9gwgBBOOFxMT63gk+nhZpGwAd4mgfbgNqN4d4Uc=";
    };
  };
in
{
  options.apps.neovim = {
    enable = lib.mkEnableOption "Enable Neovim";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.neovim ];

    home-manager.users.${username} = _: {
      programs.neovim = {
        enable = true;
        plugins = [ flexoki-neovim ];
        extraLuaConfig = ''
          vim.cmd('colorscheme flexoki-dark')
        '';
      };

      home.sessionVariables = {
        EDITOR = "nvim";
      };
    };
  };
}
