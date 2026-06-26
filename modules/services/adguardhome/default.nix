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
#   After deployment, the web dashboard is accessible via Tailscale at
#   http://<tailscale-ip>:3001 (only from the Tailscale network).
#   The initial setup wizard will run on first access.
#   To use your VPS as a DNS resolver, point your devices to the Tailscale IP on port 53.
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
    enable = lib.mkEnableOption "Enable AdGuard Home";

    dnsBindHosts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "127.0.0.1" ];
      description = "IP addresses AdGuard Home DNS should bind to";
    };
  };

  config = lib.mkIf cfg.enable {
    # Only expose AdGuard Home on Tailscale and loopback interfaces.
    # Port 53  = DNS (TCP+UDP)
    # Port 3001 = Web dashboard
    networking.firewall.interfaces = {
      tailscale0 = {
        allowedTCPPorts = [
          53
          adguardPort
        ];
        allowedUDPPorts = [ 53 ];
      };
      lo = {
        allowedTCPPorts = [
          53
          adguardPort
        ];
        allowedUDPPorts = [ 53 ];
      };
    };

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
            "https://cloudflare-dns.com/dns-query"
            "https://dns.google/dns-query"
            "https://dns.quad9.net/dns-query"
            "https://dns.mullvad.net/dns-query"
            "https://protective.joindns4.eu/dns-query"
          ];
          bootstrap_dns = [
            "1.1.1.1"
            "1.0.0.1"
            "8.8.8.8"
            "8.8.4.4"
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
          {
            enabled = true;
            url = "https://raw.githubusercontent.com/easylist/easylist/master/easylist/easylist_adservers.txt";
            name = "EasyList";
            id = 5;
          }
          {
            enabled = true;
            url = "https://raw.githubusercontent.com/easylist/easylist/master/easyprivacy/easyprivacy_trackingservers.txt";
            name = "EasyPrivacy";
            id = 6;
          }
          {
            enabled = true;
            url = "https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/filters.txt";
            name = "uBlock filters - Ads, trackers, and more";
            id = 7;
          }
          {
            enabled = true;
            url = "https://adguardteam.github.io/AdguardFilters/MobileFilter/sections/adservers.txt";
            name = "AdGuard/uBO - Mobile Ads";
            id = 8;
          }
          {
            enabled = true;
            url = "https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/privacy.txt";
            name = "AdGuard/uBO - URL Tracking Protection";
            id = 9;
          }
          {
            enabled = true;
            url = "https://raw.githubusercontent.com/DandelionSprout/adfilt/master/AdGuardHomeDisallowedIPs.txt";
            name = "Block Outsider Intrusion into LAN";
            id = 10;
          }
          {
            enabled = true;
            url = "https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/annoyances-cookies.txt";
            name = "EasyList/uBO - Cookie Notices";
            id = 11;
          }
          {
            enabled = true;
            url = "https://adguardteam.github.io/AdguardFilters/SpanishFilter/sections/adservers.txt";
            name = "es-es ar-ar br-br pt-pt: AdGuard Spanish/Portuguese";
            id = 12;
          }
          {
            enabled = true;
            url = "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/pro.txt";
            name = "HaGeZi Multi PRO";
            id = 13;
          }
        ];

        user_rules = [
          "||shorts.youtube.com^"
          "||youtube.com^$path=/shorts"
          "||www.youtube.com^$path=/shorts"

          #"||youtube.com^"
          #"||www.youtube.com^"

          "@@||music.youtube.com^"
          "@@||accounts.youtube.com^"
          "@@||studio.youtube.com^"
          "@@||upload.youtube.com^"
        ];

        filtering = {
          protection_enabled = true;
          filtering_enabled = true;
          parental_enabled = true;
          safe_search.enabled = false;

          blocked_services = {
            ids = [
              # "twitter"
              # "instagram"
              # "linkedin"
            ];
            # AdGuard blocked_services.schedule is an inactivity window.
            # 20h-24h means services are allowed at night and blocked during daytime.
            schedule = {
              time_zone = "Europe/Lisbon";
              sun = {
                start = "20h";
                end = "24h";
              };
              mon = {
                start = "20h";
                end = "24h";
              };
              tue = {
                start = "20h";
                end = "24h";
              };
              wed = {
                start = "20h";
                end = "24h";
              };
              thu = {
                start = "20h";
                end = "24h";
              };
              fri = {
                start = "20h";
                end = "24h";
              };
              sat = {
                start = "20h";
                end = "24h";
              };
            };
          };
        };
      };
    };

  };
}
