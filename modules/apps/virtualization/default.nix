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
  cfg = config.apps.virtualization;
  inherit (constants) isDarwin isLinux;
in
{
  options.apps.virtualization = {
    enable = lib.mkEnableOption "Enable virtualization (QEMU + platform-specific hypervisor)";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      # QEMU - available on both platforms
      {
        environment.systemPackages = [ pkgs.qemu ];
      }

      # Linux: VirtualBox
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.virtualbox ];
      })

      # Darwin: UTM + FUSE (install in order: macfuse first, then sshfs-mac)
      # (lib.optionalAttrs isDarwin {
      #   homebrew.casks = [ "utm" ];
      #   homebrew.onActivation = {
      #     noAutoUpdate = true;
      #     commands = [
      #       "brew install --cask macfuse"
      #       "brew install gromgit/fuse/sshfs-mac"
      #     ];
      #   };
      # })
    ]
  );
}
