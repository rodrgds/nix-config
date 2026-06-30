{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.vps.websites;

  eduPort = 3001;
  personalPort = 4321;

  eduSite = pkgs.stdenv.mkDerivation {
    pname = "edu-site";
    version = inputs.edu.shortRev or "dirty";
    src = inputs.edu;

    installPhase = ''
      mkdir -p $out
      cp -r * $out/
    '';
  };
in
{
  options.vps.websites = {
    enable = lib.mkEnableOption "Enable Websites";
    edu.enable = lib.mkEnableOption "Enable edu-site" // {
      default = true;
    };
    personal.enable = lib.mkEnableOption "Enable personal-site" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    sops.templates."personal-site-env" = lib.mkIf cfg.personal.enable {
      content = ''
        GITHUB_ACCESS_TOKEN=${config.sops.placeholder.website_github_access_token}
        HEVY_API_KEY=${config.sops.placeholder.website_hevy_api_key}
        LASTFM_API_KEY=${config.sops.placeholder.website_lastfm_api_key}
        LASTFM_USERNAME=${config.sops.placeholder.website_lastfm_username}
        TRAKT_CLIENT_ID=${config.sops.placeholder.website_trakt_client_id}
        TRAKT_CLIENT_SECRET=${config.sops.placeholder.website_trakt_client_secret}
        TMDB_API_KEY=${config.sops.placeholder.website_tmdb_api_key}
        DIRECTUS_URL=${config.sops.placeholder.website_directus_url}
        DIRECTUS_ACCESS_TOKEN=${config.sops.placeholder.website_directus_access_token}
        HOST=127.0.0.1
        PORT=${toString personalPort}
        NODE_ENV=production
      '';
      mode = "0600";
    };

    systemd.services.personal-site = lib.mkIf cfg.personal.enable {
      description = "Personal Astro Website Build";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      environment.NODE_OPTIONS = "--max-old-space-size=3072";

      path = [
        pkgs.bun
        pkgs.git
        pkgs.nodejs
        pkgs.typst
        pkgs.vips
        pkgs.glib
        pkgs.cairo
        pkgs.pango
      ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        EnvironmentFile = config.sops.templates."personal-site-env".path;
        StateDirectory = "personal-site";
        WorkingDirectory = "/var/lib/personal-site";
        MemoryHigh = "3G";
        MemoryMax = "4G";

        ExecStart = "${pkgs.bash}/bin/bash -c 'if [ ! -d /var/lib/personal-site/.git ]; then git clone https://github.com/rodrgds/personal-website /var/lib/personal-site; fi && cd /var/lib/personal-site && git fetch origin main && git reset --hard origin/main && bun install && bun run build'";
        ExecStartPost = "${pkgs.systemd}/bin/systemctl --no-block try-restart personal-site-run.service";
      };
    };

    systemd.services.personal-site-run = lib.mkIf cfg.personal.enable {
      description = "Personal Astro Website Server";
      after = [ "personal-site.service" ];
      wantedBy = [ "multi-user.target" ];
      wants = [ "personal-site.service" ];

      path = [ pkgs.bun ];

      environment.LD_LIBRARY_PATH = lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ];

      serviceConfig = {
        Type = "simple";
        EnvironmentFile = config.sops.templates."personal-site-env".path;
        StateDirectory = "personal-site";
        WorkingDirectory = "/var/lib/personal-site";
        ExecStart = "${pkgs.bun}/bin/bun run dist/server/entry.mjs";
        Restart = "always";
      };
    };

    vps.caddy.internalPorts = lib.mkIf cfg.personal.enable {
      personal = personalPort;
    };

    services.caddy.virtualHosts =
      lib.mkIf cfg.edu.enable {
        "edu.rgo.pt" = {
          extraConfig = ''
            root * ${eduSite}
            file_server
          '';
        };
      }
      // lib.mkIf cfg.personal.enable {
        "rgo.pt" = {
          extraConfig = ''
            handle /_astro/* {
              root * /var/lib/personal-site/dist/client
              header Cache-Control "public, max-age=31536000, immutable"
              file_server
            }

            handle {
              reverse_proxy 127.0.0.1:${toString personalPort}
            }
          '';
        };
      };
  };
}
