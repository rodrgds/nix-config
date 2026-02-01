{
  lib,
  config,
  pkgs,
  system,
  ...
}:
let
  cfg = config.apps.stremio;
  isDarwin = lib.hasSuffix "-darwin" system;
  isLinux = lib.hasSuffix "-linux" system;
in
{
  options.apps.stremio = {
    enable = lib.mkEnableOption "Enable Stremio";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      # Linux: Install via nixpkgs
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.stremio ];
      })
      # Darwin: Install via Homebrew (only if on Darwin)
      (lib.optionalAttrs isDarwin {
        homebrew.casks = [ "stremio" ];
      })
    ]
  );
}
