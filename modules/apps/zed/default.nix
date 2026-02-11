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
  cfg = config.apps.zed;
  inherit (constants) isDarwin isLinux;
in
{
  options.apps.zed = {
    enable = lib.mkEnableOption "Enable Zed Editor";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      # Linux: Install via nixpkgs
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.zed-editor ];
      })
      # Darwin: Install via Homebrew cask
      (lib.optionalAttrs isDarwin {
        homebrew.casks = [ "zed" ];
      })
    ]
  );
}
