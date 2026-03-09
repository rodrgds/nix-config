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
  cfg = config.apps.stremio;
  inherit (constants) isDarwin isLinux;
in
{
  options.apps.stremio = {
    enable = lib.mkEnableOption "Enable Stremio";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      # Linux: Install via nixpkgs
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.stremio-linux-shell ];
      })
      # Darwin: Install via Homebrew (only if on Darwin)
      (lib.optionalAttrs isDarwin {
        homebrew.casks = [ "stremio" ];
      })
    ]
  );
}
