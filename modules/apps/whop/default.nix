{
  config,
  lib,
  constants,
  ...
}:
let
  cfg = config.apps.whop;
  inherit (constants) isDarwin;
in
{
  options.apps.whop = {
    enable = lib.mkEnableOption "Enable the Whop CLI";
  };

  config = lib.optionalAttrs isDarwin {
    homebrew = lib.mkIf cfg.enable {
      taps = [
        {
          name = "whopio/tap";
          trusted = true;
        }
      ];
      brews = [ "whopio/tap/whop" ];
    };
  };
}
