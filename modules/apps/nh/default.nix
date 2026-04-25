{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.nh;
  inherit (constants) isDarwin;
in
{
  options.apps.nh = {
    enable = lib.mkEnableOption "Enable nh (nix helper) for better rebuild and cleanup experience";
  };

  config = lib.mkIf cfg.enable (
    {
      # On Darwin, just install the package since there's no native module.
      home-manager.users.${username} = lib.mkIf isDarwin {
        home.packages = [ pkgs.nh ];
      };
    }
    // lib.optionalAttrs (!isDarwin) {
      # On NixOS, use the native programs.nh module for completions and default flake path.
      programs.nh = {
        enable = true;
        flake = "/home/${username}/.config/home";
      };
    }
  );
}
