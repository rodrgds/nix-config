{
  lib,
  config,
  pkgs,
  username,
  system,
  constants,
  ...
}:
let
  cfg = config.apps.beeper;
  inherit (constants) isDarwin isLinux;
in
{
  options.apps.beeper = {
    enable = lib.mkEnableOption "Enable Beeper";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      # Linux: Install via nixpkgs
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.beeper ];
      })
      # Darwin: Install via Homebrew (only if on Darwin)
      (lib.optionalAttrs isDarwin {
        homebrew.taps = [ "beeper/tap" ];
        homebrew.casks = [ "beeper" ];
        homebrew.brews = [ "beeper/tap/cli" ];
      })
    ]
  );
}
