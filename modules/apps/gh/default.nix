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
    enable = lib.mkEnableOption "Enable gh";
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
        home-manager.users.${username} = _: {
          # to get auth for projects: gh auth refresh -s project
          programs.gh = {
            enable = true;
            gitCredentialHelper = {
              enable = true;
            };
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
