# Host-specific hardware configuration
_: {
  services.xserver.screenSection = ''
    Option "metamodes" "DP-0: 1920x1080_144 @1920x1080 +0+0 {ViewPortIn=1920x1080, ViewPortOut=1920x1080+0+0, ForceCompositionPipeline=On, ForceFullCompositionPipeline=On}, HDMI-0: 1920x1080_144 @1920x1080 +1920+0 {ViewPortIn=1920x1080, ViewPortOut=1920x1080+0+0, ForceCompositionPipeline=On, ForceFullCompositionPipeline=On}"
  '';

  fileSystems."/home/rgo/hdd" = {
    device = "/dev/disk/by-uuid/EA64AE7864AE4763";
    fsType = "ntfs";
    options = [
      "rw"
      "uid=1000"
      "gid=100"
      "umask=0022"
      "nofail"
    ];
  };

  # Via NFS, the NAS trusts the local machine based on its IP address
  fileSystems."/home/rgo/nas" = {
    device = "synology:/volume1/homes/kraktoos";
    fsType = "nfs";
    options = [
      "x-systemd.automount"
      "noauto"
    ];
  };
}
