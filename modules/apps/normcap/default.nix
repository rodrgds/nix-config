{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.normcap;
  inherit (constants) isLinux;
in
{
  options.apps.normcap = {
    enable = lib.mkEnableOption "Enable Normcap";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.normcap ];
      })
    ]
  );
}
