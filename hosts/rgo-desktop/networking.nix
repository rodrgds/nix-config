# Host-specific networking configuration
_: {
  networking.hostName = "rgo-desktop";

  # Keep the desktop on the address trusted by the NAS, but let one network
  # stack own the interface. Mixing scripted addresses, dhcpcd, and
  # NetworkManager gave this NIC two IPv4 addresses and two default routes.
  networking.networkmanager.ensureProfiles.profiles.enp7s0 = {
    connection = {
      id = "enp7s0";
      type = "ethernet";
      interface-name = "enp7s0";
      autoconnect = true;
    };
    ethernet = { };
    ipv4 = {
      method = "manual";
      address1 = "192.168.1.69/24,192.168.1.254";
      dns = "192.168.1.254;";
    };
    ipv6 = {
      method = "auto";
      addr-gen-mode = "stable-privacy";
    };
  };

  networking.hosts = {
    "192.168.1.100" = [ "synology" ];
  };
}
