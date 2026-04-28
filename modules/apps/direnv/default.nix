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
    # Enable system-level direnv on NixOS so angrr can hook into /etc/direnv/lib
    programs.direnv.enable = lib.mkIf (!isDarwin) true;

    home-manager.users.${username} = {
      programs.direnv = {
        enable = true;
        enableZshIntegration = true;
        enableBashIntegration = true;
        enableFishIntegration = true;
        nix-direnv.enable = true;
      };
    };
  };
}
