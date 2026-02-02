{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.charm-freeze;
  inherit (constants) isLinux;
in
{
  options.apps.charm-freeze = {
    enable = lib.mkEnableOption "Enable Charm Freeze";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.charm-freeze ];
      })
    ]
  );
}
