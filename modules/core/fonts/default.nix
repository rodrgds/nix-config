{
  lib,
  config,
  pkgs,
  ...
}:
let
  fonts = import ./packages.nix { inherit pkgs; };
  cfg = config.core.fonts;
in
{
  options.core.fonts = {
    enable = lib.mkEnableOption "Enable fonts configuration";
    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [];
      description = "Additional font packages to install";
    };
  };

  config = lib.mkIf cfg.enable {
    fonts.packages = fonts.sharedPackages
      ++ fonts.linuxOnlyPackages
      ++ cfg.extraPackages;
  };
}
