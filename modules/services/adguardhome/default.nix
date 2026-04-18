# AdGuard Home - Network-wide ad blocker
# https://github.com/AdguardTeam/AdGuardHome
#
# AdGuard Home provides DNS-level ad blocking, tracking protection,
# and a web dashboard for managing filters and viewing query logs.
#
# Unlike other VPS services, this uses the native NixOS service
# (not a podman container) since AdGuard Home is well-packaged in nixpkgs.
#
# FIRST-TIME SETUP:
#   After deployment, the web dashboard is accessible at https://dns.rgo.pt
#   The initial setup wizard will run on first access.
#   To use your VPS as a DNS resolver, point your devices/router to the VPS IP on port 53.
#
{
  config,
  lib,
  ...
}:
let
  cfg = config.vps.adguardhome;

  adguardPort = 3001;
in
{
  options.vps.adguardhome = {
    enable = lib.mkEnableOption "AdGuard Home network-wide ad blocker";

    domain = lib.mkOption {
      type = lib.types.str;
      default = "dns.rgo.pt";
      description = "Domain for AdGuard Home web interface";
    };

    dnsBindHosts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "0.0.0.0" ];
      description = "IP addresses AdGuard Home DNS should bind to";
    };
  };

  config = lib.mkIf cfg.enable {
    # Open DNS port on firewall (both TCP and UDP)
    networking.firewall.allowedTCPPorts = [ 53 ];
    networking.firewall.allowedUDPPorts = [ 53 ];

    # AdGuard Home service (native NixOS, not podman)
    services.adguardhome = {
      enable = true;
      openFirewall = false; # We manage firewall manually above
      mutableSettings = false;
      host = "0.0.0.0";
      port = adguardPort;

      settings = {
        http.address = "0.0.0.0:${toString adguardPort}";

        querylog.enabled = true;
        statistics.enabled = true;

        dns = {
          bind_hosts = cfg.dnsBindHosts;
          port = 53;
          upstream_dns = [
            "https://dns.quad9.net/dns-query"
            "https://dns.mullvad.net/dns-query"
          ];
          bootstrap_dns = [
            "9.9.9.9"
            "149.112.112.112"
          ];
          cache_size = 4194304;
          cache_ttl_min = 2400;
        };

        filters = [
          {
            enabled = true;
            url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt";
            name = "AdGuard DNS filter";
            id = 1;
          }
          {
            enabled = true;
            url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_2.txt";
            name = "AdAway Default Blocklist";
            id = 2;
          }
          {
            enabled = true;
            url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_9.txt";
            name = "The Big List of Hacked Malware Web Sites";
            id = 3;
          }
          {
            enabled = true;
            url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_11.txt";
            name = "Malicious URL Blocklist";
            id = 4;
          }
        ];

        user_rules = [
          "||shorts.youtube.com^"
          "||youtube.com^$path=/shorts"
          "||www.youtube.com^$path=/shorts"
        ];

        filtering = {
          protection_enabled = true;
          filtering_enabled = true;
          parental_enabled = true;
          safe_search.enabled = false;

          blocked_services = {
            ids = [ "twitter" ];
            schedule = {
              time_zone = "Local";
              sun = { start = "0s"; end = "13h"; };
              mon = { start = "0s"; end = "13h"; };
              tue = { start = "0s"; end = "13h"; };
              wed = { start = "0s"; end = "13h"; };
              thu = { start = "0s"; end = "13h"; };
              fri = { start = "0s"; end = "13h"; };
              sat = { start = "0s"; end = "13h"; };
            };
          };
        };
      };
    };

    # Caddy reverse proxy for web dashboard
    vps.caddy.internalPorts.${cfg.domain} = adguardPort;
  };
}
