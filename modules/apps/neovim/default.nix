{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.neovim;

  flexoki-neovim = pkgs.vimUtils.buildVimPlugin {
    pname = "flexoki-neovim";
    version = "main";
    src = pkgs.fetchFromGitHub {
      owner = "kepano";
      repo = "flexoki-neovim";
      rev = "main";
      hash = "sha256-TlBP99MBAT/H0Uut1MF8SnIDoeetcdHLKrWal2oO2Ug=";
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
        # Preserve the pre-26.05 provider behavior explicitly.
        withPython3 = true;
        withRuby = true;
        plugins = [ flexoki-neovim ];
        initLua = ''
          vim.cmd('colorscheme flexoki-dark')
        '';
      };

      home.sessionVariables = {
        EDITOR = "nvim";
      };
    };
  };
}
