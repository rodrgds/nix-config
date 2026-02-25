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
  cfg = config.apps.utm;
  inherit (constants) isDarwin isLinux;
in
{
  options.apps.utm = {
    enable = lib.mkEnableOption "Enable UTM";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      # Linux: Not available on NixOS (use libvirt/qemu instead)
      # Darwin: Install via Homebrew cask
      (lib.optionalAttrs isDarwin {
        homebrew.casks = [ "utm" ];
      })
    ]
  );
}
