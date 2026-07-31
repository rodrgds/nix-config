{
  lib,
  config,
  ...
}:
let
  cfg = config.apps.comma;
in
{
  options.apps.comma = {
    enable = lib.mkEnableOption "Enable comma";
  };

  config = lib.mkIf cfg.enable {
    # nix-index-database module provides a nix-index wrapper with the pre-built database.
    # Enabling comma here installs comma wrapped with the same database.
    programs.nix-index-database.comma.enable = true;
  };
}
