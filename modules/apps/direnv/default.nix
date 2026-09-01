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
    enable = lib.mkEnableOption "Enable direnv";
  };

  config = lib.mkIf cfg.enable {
    # Enable system-level direnv on NixOS so angrr can hook into /etc/direnv/lib
    programs.direnv.enable = lib.mkIf (!isDarwin) true;

    home-manager.users.${username} = {
      programs.direnv = {
        enable = true;
        # NixOS already installs these hooks system-wide. Home Manager owns
        # them only on Darwin so each prompt runs direnv once.
        enableZshIntegration = isDarwin;
        enableBashIntegration = isDarwin;
        enableFishIntegration = isDarwin;
        nix-direnv.enable = true;
      };
    };
  };
}
