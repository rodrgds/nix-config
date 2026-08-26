{
  lib,
  config,
  pkgs,
  constants,
  ...
}:
let
  cfg = config.apps.google-chrome;
  inherit (constants) isDarwin isLinux;
in
{
  options.apps.google-chrome = {
    enable = lib.mkEnableOption "Enable Google Chrome";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      # Linux: Install via nixpkgs (only if on Linux)
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.google-chrome ];
      })
      # Darwin: Install via Homebrew (only if on Darwin)
      (lib.optionalAttrs isDarwin {
        homebrew.casks = [ "google-chrome" ];
      })
    ]
  );
}
