{
  lib,
  config,
  pkgs,
  username,
  system,
  constants,
  ...
}:
let
  cfg = config.apps.flameshot;
  inherit (constants) isLinux isDarwin;
in
{
  options.apps.flameshot = {
    enable = lib.mkEnableOption "Enable Flameshot";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.flameshot ];
      })
      (lib.optionalAttrs isDarwin {
        homebrew.casks = [ "flameshot" ];
      })
    ]
  );
}
