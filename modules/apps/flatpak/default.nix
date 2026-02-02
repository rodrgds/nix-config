{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.flatpak;
  inherit (constants) isLinux;
in
{
  options.apps.flatpak = {
    enable = lib.mkEnableOption "Enable Flatpak support";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        services.flatpak.enable = true;
      })
    ]
  );
}
