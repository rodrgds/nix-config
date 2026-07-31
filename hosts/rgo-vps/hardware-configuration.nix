# Hetzner Cloud VPS hardware profile
# Keep this file small and stable; Disk/FS comes from disko.nix.
{ lib, modulesPath, ... }:
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # Hetzner Cloud typically provides IPv4 via DHCP.
  networking.useDHCP = lib.mkDefault true;
}
