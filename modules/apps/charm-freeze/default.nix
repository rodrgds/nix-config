{
  lib,
  config,
  pkgs,
  username,
  system,
  ...
}:
let
  cfg = config.apps.charm-freeze;
  isLinux = lib.hasSuffix "-linux" system;
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
