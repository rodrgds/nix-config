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
  cfg = config.apps.virtualbox;
  inherit (constants) isDarwin isLinux;
in
{
  options.apps.virtualbox = {
    enable = lib.mkEnableOption "Enable VirtualBox";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      # Linux: Install via nixpkgs
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.virtualbox ];
      })
      # Darwin: Install via Homebrew cask
      (lib.optionalAttrs isDarwin {
        homebrew.casks = [ "virtualbox" ];
      })
    ]
  );
}
