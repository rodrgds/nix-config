# Immich Public Proxy
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.vps.immich-public-proxy;
  immichPort = 3008;
in
{
  options.vps.immich-public-proxy = {
    enable = lib.mkEnableOption "Enable Immich Public Proxy";
    immichUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://100.88.5.41:8212";
      description = "URL of Immich server";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.containers.immich-public-proxy = {
      image = "alangrainger/immich-public-proxy:latest";

      environment = {
        IMMICH_URL = cfg.immichUrl;
      };

      ports = [
        "127.0.0.1:${toString immichPort}:80"
      ];

      extraOptions = [
        "--network=podman"
        "--restart=always"
      ];
    };

    vps.caddy.internalPorts.immich-public-proxy = immichPort;

    services.caddy.virtualHosts."photos.rgo.pt" = {
      logFormat = config.vps.caddy.accessLogFor "photos.rgo.pt";
      extraConfig = ''
        reverse_proxy 127.0.0.1:${toString immichPort}
      '';
    };
  };
}
