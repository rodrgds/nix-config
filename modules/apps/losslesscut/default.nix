{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.losslesscut;
  inherit (constants) isLinux isDarwin;
in
{
  options.apps.losslesscut = {
    enable = lib.mkEnableOption "Enable LosslessCut";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.unstable.losslesscut-bin ];
      })
      (lib.optionalAttrs isDarwin {
        homebrew.casks = [ "losslesscut" ];
      })
    ]
  );
}
