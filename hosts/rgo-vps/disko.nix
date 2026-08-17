# Disk layout for Hetzner Cloud (x86_64, BIOS boot)
# Used by nixos-anywhere + disko during installation.
let
  rootUuid = (import ./root-disk.nix).uuid;
in
{
  disko.devices = {
    disk.main = {
      type = "disk";
      device = "/dev/sda";
      content = {
        type = "gpt";
        partitions = {
          # BIOS boot partition for GRUB on GPT.
          boot = {
            size = "1M";
            type = "EF02";
            priority = 1;
          };

          # Filesystem mounted at /boot.
          ESP = {
            size = "512M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
            };
          };

          root = {
            size = "100%";
            content = {
              type = "filesystem";
              format = "ext4";
              # Pin the live root filesystem's UUID so a disaster-recovery
              # reinstall reproduces it. The host mounts "/" by this UUID (not
              # the GPT partlabel) to survive GPT name loss (see root-disk.nix).
              extraArgs = [
                "-U"
                rootUuid
              ];
              mountpoint = "/";
            };
          };
        };
      };
    };
  };
}
