{
  lib,
  config,
  ...
}:
let
  cfg = config.core.angrr;
in
{
  options.core.angrr = {
    enable = lib.mkEnableOption "Enable angrr";
  };

  config = lib.mkIf cfg.enable {
    services.angrr = {
      enable = true;
      period = "7d";
    };

    # The scheduled service still protects recent direnv roots before Nix GC.
    # Avoid rescanning every project GC root on each directory activation.
    programs.direnv.angrr.autoUse = false;
  };
}
