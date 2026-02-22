{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.gh;
  inherit (constants) isDarwin isLinux;
in
{
  options.apps.gh = {
    enable = lib.mkEnableOption "Enable GitHub CLI (gh)";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.gh ];
      })
      (lib.optionalAttrs isDarwin {
        homebrew.brews = [ "gh" ];
      })
      {
        home-manager.users.${username} =
          { ... }:
          {
            programs.gh = {
              enable = true;
              settings = {
                git_protocol = "ssh";
                prompt = "enabled";
              };
            };
          };
      }
    ]
  );
}
