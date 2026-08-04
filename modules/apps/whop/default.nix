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

  config = lib.mkIf (cfg.enable && isDarwin) {
    homebrew.taps = [
      {
        name = "whopio/tap";
        trusted = true;
      }
    ];
    homebrew.brews = [ "whopio/tap/whop" ];
  };
}
