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

        # ARM-specific VirtualBox configuration for Apple Silicon Macs
        # Enable x86 emulation on ARM (VirtualBox needs this for Intel VMs on M1/M2/M3/M4)
        # This command enables VirtualBox to run x86/x64 VMs on Apple Silicon
        # Run manually after installation: VBoxManage setextradata global "VBoxInternal2/EnableX86OnArm" 1
      })
    ]
  );
}
