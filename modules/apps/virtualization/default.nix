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
    enable = lib.mkEnableOption "Enable virtualization";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      # QEMU - available on both platforms
      {
        environment.systemPackages = [ pkgs.qemu ];
      }

      # Linux: VirtualBox (uses NixOS module for kernel drivers)
      (lib.optionalAttrs isLinux {
        virtualisation.virtualbox.host.enable = true;
        users.users.${username}.extraGroups = [ "vboxusers" ];
      })

      # Darwin: UTM + VirtualBox + FUSE (install in order: macfuse first, then sshfs-mac)
      (lib.optionalAttrs isDarwin {
        homebrew.casks = [
          "utm"
          "virtualbox"
        ];
        #   homebrew.onActivation = {
        #     noAutoUpdate = true;
        #     commands = [
        #       "brew install --cask macfuse"
        #       "brew install gromgit/fuse/sshfs-mac"
        #     ];
        #   };
      })
    ]
  );
}
