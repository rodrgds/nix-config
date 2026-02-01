# Host-specific networking configuration
{ ... }:
{
  networking.hostName = "rgo-desktop";

  networking.interfaces.enp7s0 = {
    useDHCP = true;
    ipv4.addresses = [
      {
        address = "192.168.1.69";
        prefixLength = 24;
      }
    ];
  };

  networking.defaultGateway = "192.168.1.254";
  networking.nameservers = [
    "1.1.1.1"
    "8.8.8.8"
  ];

  networking.hosts = {
    "192.168.1.100" = [ "synology" ];
  };
}
