# Caddy reverse proxy for VPS services
# Handles automatic HTTPS and subdomain routing
{
  config,
  lib,
  ...
}:
let
  cfg = config.vps.caddy;
in
{
  options.vps.caddy = {
    enable = lib.mkEnableOption "Caddy reverse proxy";

    internalPorts = lib.mkOption {
      type = lib.types.attrsOf lib.types.int;
      default = { };
      description = "Map of service names to internal ports";
    };
  };

  config = lib.mkIf cfg.enable {
    services.caddy = {
      enable = true;

      virtualHosts = {
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

        # Umami - analytics
        "analytics.rgo.pt" = {
          extraConfig = ''
            reverse_proxy localhost:${toString (cfg.internalPorts.umami or 3000)}

            header {
              Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
              X-Content-Type-Options "nosniff"
              X-Frame-Options "SAMEORIGIN"
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

        # Directus CMS
        "directus.rgo.pt" = {
          extraConfig = ''
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
      };
    };
  };
}
