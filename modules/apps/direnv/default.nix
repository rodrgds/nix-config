{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.direnv;
  inherit (constants) isDarwin;
in
{
  options.apps.direnv = {
    enable = lib.mkEnableOption "Enable direnv with nix-direnv support";
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${username} = {
      programs.direnv = {
        enable = true;
        enableZshIntegration = true;
        enableFishIntegration = true;
        nix-direnv.enable = true;
      };
    };
  };
}
