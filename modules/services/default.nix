# Server services module
# Central module for all containerized services on the VPS
{
  lib,
  config,
  username,
  ...
}:
{
  imports = [
    ./caddy
    ./podman
    ./n8n
    ./unieasy
    ./umami
    ./ghost
    ./vaultwarden
    ./shlink
    ./teamspeak
    ./postiz
    ./websites
    ./pocketbase
    ./deploy
    ./directus
    ./trndb
    ./immich-public-proxy
    ./termix
  ];

  options.vps.enableAll = lib.mkEnableOption "Enable all VPS services (Caddy reverse proxy + containerized apps)";

  # Note: Individual services are enabled separately via vps.* namespace
}
