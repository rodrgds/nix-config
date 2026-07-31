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
  cfg = config.apps.clion;
  inherit (constants) isDarwin isLinux;
in
{
  options.apps.clion = {
    enable = lib.mkEnableOption "Enable CLion";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      # Linux: Install via nixpkgs
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.jetbrains.clion ];
      })
      # Darwin: Install via Homebrew cask
      (lib.optionalAttrs isDarwin {
        homebrew.casks = [ "clion" ];
      })
    ]
  );
}
