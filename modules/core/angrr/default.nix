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
  };
}
