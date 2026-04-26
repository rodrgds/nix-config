{ lib, config, ... }:
let
  cfg = config.core.printing;
in
{
  options.core.printing = {
    enable = lib.mkEnableOption "Enable printing support";
  };

  config = lib.mkIf cfg.enable {
    services.printing.enable = true;
  };
}
