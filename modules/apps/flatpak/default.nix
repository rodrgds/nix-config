{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.flatpak;
in
{
  options.apps.flatpak = {
    enable = lib.mkEnableOption "Enable Flatpak support";
  };

  config = lib.mkIf cfg.enable {
    services.flatpak.enable = true;
  };
}
