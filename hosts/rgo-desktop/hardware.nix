# Host-specific hardware configuration
{ pkgs, ... }:
{
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
    fsType = "nfs4";
    options = [
      "x-systemd.automount"
      "x-systemd.idle-timeout=10min"
      "noauto"
      "nofail"
      "_netdev"
      "nfsvers=4.1"
    ];
  };

  # Keep the on-demand mount as a fallback, but start it in the background once
  # networking is online. This prevents the first Starship prompt after boot
  # from being the process that accidentally triggers (and waits for) the NAS.
  systemd.services.nas-mount-at-boot = {
    description = "Start the NAS mount after networking is online";
    wantedBy = [ "multi-user.target" ];
    wants = [
      "network-online.target"
      "home-rgo-nas.mount"
    ];
    after = [ "network-online.target" ];

    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.coreutils}/bin/true";
    };
  };
}
