{
  lib,
  config,
  pkgs,
  system,
  ...
}:
let
  cfg = config.apps.beeper;
  isDarwin = lib.hasSuffix "-darwin" system;
  isLinux = lib.hasSuffix "-linux" system;
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
        homebrew.casks = [ "beeper" ];
      })
    ]
  );
}
