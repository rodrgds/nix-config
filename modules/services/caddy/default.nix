# Caddy reverse proxy for VPS services
# Handles automatic HTTPS and subdomain routing
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.vps.caddy;

  staticVirtualHosts = {
    # n8n - workflow automation
    "n8n.rgo.pt" = {
      extraConfig = ''
        reverse_proxy localhost:${toString (cfg.internalPorts.n8n or 5678)}

        # Security headers
        header {
          Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
          X-Content-Type-Options "nosniff"
          X-Frame-Options "DENY"
          X-XSS-Protection "1; mode=block"
          Referrer-Policy "strict-origin-when-cross-origin"
        }
      '';
    };

    # Ghost - blog
    "cs.rgo.pt" = {
      extraConfig = ''
        reverse_proxy localhost:${toString (cfg.internalPorts.ghost or 2368)}

        header {
          Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
          X-Content-Type-Options "nosniff"
          X-Frame-Options "SAMEORIGIN"
          X-XSS-Protection "1; mode=block"
          Referrer-Policy "strict-origin-when-cross-origin"
        }
      '';
    };

    # Vaultwarden - password manager
    "vault.rgo.pt" = {
      extraConfig = ''
        reverse_proxy localhost:${toString (cfg.internalPorts.vaultwarden or 80)}

        # Vaultwarden-specific settings
        header {
          Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
          X-Content-Type-Options "nosniff"
          X-Robots-Tag "noindex, nofollow"
        }
      '';
    };

    # Postiz - social media scheduler
    "postiz.rgo.pt" = {
      extraConfig = ''
        reverse_proxy localhost:${toString (cfg.internalPorts.postiz or 5000)}

        header {
          Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
          X-Content-Type-Options "nosniff"
          X-Frame-Options "SAMEORIGIN"
          X-XSS-Protection "1; mode=block"
          Referrer-Policy "strict-origin-when-cross-origin"
        }
      '';
    };

    # Temporal UI - Postiz workflow monitoring
    "temporal.rgo.pt" = {
      extraConfig = ''
        reverse_proxy localhost:${toString (cfg.internalPorts.postiz-temporal-ui or 8080)}

        header {
          Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
          X-Content-Type-Options "nosniff"
          X-Frame-Options "SAMEORIGIN"
          X-XSS-Protection "1; mode=block"
          Referrer-Policy "strict-origin-when-cross-origin"
        }
      '';
    };

    # Deploy webhook - GitHub push-to-deploy
    "webhooks.rgo.pt" = {
      extraConfig = ''
        reverse_proxy localhost:${toString (cfg.internalPorts."webhooks.rgo.pt" or 9000)}
      '';
    };

    # OpenPost former app host
    "app.openpost.social" = {
      extraConfig = ''
        redir https://app.openpo.st{uri} permanent
      '';
    };

    # OpenPost canonical app host
    "app.openpo.st" = {
      extraConfig = ''
        reverse_proxy localhost:${toString (cfg.internalPorts.openpost or 8090)}

        header {
          Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
          X-Content-Type-Options "nosniff"
          X-Frame-Options "SAMEORIGIN"
          X-XSS-Protection "1; mode=block"
          Referrer-Policy "strict-origin-when-cross-origin"
        }
      '';
    };

    # Redirect old domain to app
    "openpost.rgo.pt" = {
      extraConfig = ''
        redir https://app.openpo.st{uri} permanent
      '';
    };

    # Directus CMS
    "directus.rgo.pt" = {
      extraConfig = ''
        # Keep CMS administration private across upstream upgrades. Allow only
        # Tailnet and loopback connection peers, never caller-supplied
        # forwarding headers.
        @outsideTailnet {
          not remote_ip 100.64.0.0/10 fd7a:115c:a1e0::/48 127.0.0.1 ::1
        }
        respond @outsideTailnet 403
        reverse_proxy localhost:${toString (cfg.internalPorts.directus or 8055)}

        header {
          Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
          X-Content-Type-Options "nosniff"
          X-Frame-Options "SAMEORIGIN"
          X-XSS-Protection "1; mode=block"
        }
      '';
    };

    # TRNDb CMS
    "trndb.rgo.pt" = {
      extraConfig = ''
        reverse_proxy localhost:${toString (cfg.internalPorts.trndb or 8056)}

        header {
          Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
          X-Content-Type-Options "nosniff"
          X-Frame-Options "SAMEORIGIN"
          X-XSS-Protection "1; mode=block"
        }
      '';
    };

    # Shlink - URL shortener (short links)
    "url.rgo.pt" = {
      extraConfig = ''
        reverse_proxy localhost:${toString (cfg.internalPorts."url.rgo.pt" or 8087)}

        header {
          Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
          X-Content-Type-Options "nosniff"
          X-Robots-Tag "noindex, nofollow"
        }
      '';
    };

    "ref.rgo.pt" = {
      extraConfig = ''
        reverse_proxy localhost:${toString (cfg.internalPorts."ref.rgo.pt" or 8087)}

        header {
          Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
          X-Content-Type-Options "nosniff"
          X-Robots-Tag "noindex, nofollow"
        }
      '';
    };

    # Shlink Web Client - admin UI
    "shlink-admin.rgo.pt" = {
      extraConfig = ''
        reverse_proxy localhost:${toString (cfg.internalPorts."shlink-admin.rgo.pt" or 8088)}

        header {
          Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
          X-Content-Type-Options "nosniff"
          X-Frame-Options "SAMEORIGIN"
          X-XSS-Protection "1; mode=block"
          Referrer-Policy "strict-origin-when-cross-origin"
        }
      '';
    };
  }
  // lib.optionalAttrs config.vps.umami.enable {
    # Umami - analytics
    "cool.rgo.pt" = {
      extraConfig = ''
        reverse_proxy localhost:${toString (cfg.internalPorts.umami or 3000)} {
          # GHSA-3xx8-742v-m4mq: tracking JWTs are accepted as share tokens.
          # Disable share-link authorization at the public boundary until
          # upstream distinguishes these tokens. Normal login and collection
          # remain available.
          header_up -X-Umami-Share-Token
          header_up -X-Umami-Share-Context
        }

        header {
          Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
          X-Content-Type-Options "nosniff"
          X-Frame-Options "SAMEORIGIN"
          X-XSS-Protection "1; mode=block"
          Referrer-Policy "strict-origin-when-cross-origin"
        }
      '';
    };
  };

  # A disabled service must not leave a proxy to a reusable loopback port.
  # Registration is owned by each enabled service, including custom domains.
  staticUpstreams = {
    "n8n.rgo.pt" = "n8n";
    "cs.rgo.pt" = "ghost";
    "vault.rgo.pt" = "vaultwarden";
    "postiz.rgo.pt" = "postiz";
    "temporal.rgo.pt" = "postiz-temporal-ui";
    "webhooks.rgo.pt" = "webhooks.rgo.pt";
    "app.openpo.st" = "openpost";
    "directus.rgo.pt" = "directus";
    "trndb.rgo.pt" = "trndb";
    "url.rgo.pt" = "url.rgo.pt";
    "ref.rgo.pt" = "ref.rgo.pt";
    "shlink-admin.rgo.pt" = "shlink-admin.rgo.pt";
  };
  activeStaticVirtualHosts = lib.filterAttrs (
    domain: _:
    !(builtins.hasAttr domain staticUpstreams)
    || builtins.hasAttr staticUpstreams.${domain} cfg.internalPorts
  ) staticVirtualHosts;

  dynamicVirtualHosts =
    lib.mapAttrs'
      (
        domain: port:
        lib.nameValuePair domain {
          extraConfig = ''
            reverse_proxy localhost:${toString port}
          '';
        }
      )
      (
        lib.filterAttrs (
          name: _: (builtins.match ".*\\..*" name) != null && !(builtins.hasAttr name staticVirtualHosts)
        ) cfg.internalPorts
      );

  # Keep per-site logs bounded. With 19 generated hosts, a 6 MiB active file
  # plus one retained roll caps aggregate access logs near 228 MiB.
  mkAccessLog =
    domain:
    let
      logName = builtins.replaceStrings [ "/" "*" ":" ] [ "_" "_" "_" ] domain;
    in
    ''
      output file /var/log/caddy/access-${logName}.log {
        roll_size 6MiB
        roll_keep 1
        roll_keep_for 168h
      }
      format json
    '';

  withAccessLog = domain: virtualHost: virtualHost // { logFormat = cfg.accessLogFor domain; };
in
{
  options.vps.caddy = {
    enable = lib.mkEnableOption "Enable Caddy";

    internalPorts = lib.mkOption {
      type = lib.types.attrsOf lib.types.int;
      default = { };
      description = "Map of service names to internal ports";
    };

    accessLogFor = lib.mkOption {
      type = lib.types.functionTo lib.types.lines;
      default = mkAccessLog;
      internal = true;
      description = "Build the shared bounded access-log policy for a Caddy virtual host";
    };
  };

  config = lib.mkIf cfg.enable {
    services.caddy = {
      enable = true;
      # GHSA-8qx7-j2v2-x6q5 affects both locked package sets at 2.11.4.
      package = pkgs.callPackage ./_package.nix { };

      virtualHosts = lib.mapAttrs withAccessLog (activeStaticVirtualHosts // dynamicVirtualHosts);
    };
  };
}
