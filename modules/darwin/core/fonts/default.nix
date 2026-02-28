{
  lib,
  config,
  pkgs,
  ...
}:
let
  fonts = import ../../../core/fonts/packages.nix { inherit pkgs; };
  cfg = config.darwin.core.fonts;
in
{
  options.darwin.core.fonts = {
    enable = lib.mkEnableOption "Enable Darwin fonts configuration";
    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Additional font packages to install";
    };
  };

  config = lib.mkIf cfg.enable {
    fonts.packages = fonts.sharedPackages ++ cfg.extraPackages;
  };
}
