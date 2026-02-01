{
  lib,
  config,
  pkgs,
  username,
  system,
  ...
}:
let
  cfg = config.apps.flatpak;
  isLinux = lib.hasSuffix "-linux" system;
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
