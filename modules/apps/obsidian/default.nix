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
  cfg = config.apps.obsidian;
  inherit (constants) isDarwin isLinux;
in
{
  options.apps.obsidian = {
    enable = lib.mkEnableOption "Enable Obsidian";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      # Linux: Install via nixpkgs
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.obsidian ];
      })
      # Darwin: Install via Homebrew cask
      (lib.optionalAttrs isDarwin {
        homebrew.casks = [ "obsidian" ];
      })
    ]
  );
}
