{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.vps.openpost-radio;
in
{
  options.vps.openpost-radio.enable = lib.mkEnableOption "OpenPost Radio packet relay";
  config = lib.mkIf cfg.enable {
    users.groups.openpost-radio = { };
    users.users.openpost-radio = {
      isSystemUser = true;
      group = "openpost-radio";
    };
    sops.secrets.openpost-radio-env = {
      sopsFile = ../../../secrets/openpost-radio-env;
      format = "binary";
      key = "";
    };
    sops.secrets.openpost-radio-nas-key = {
      sopsFile = ../../../secrets/openpost-radio-nas-key;
      format = "binary";
      key = "";
    };
    systemd.tmpfiles.rules = [ "d /opt/openpost-radio 0755 root root -" ];
    systemd.services.openpost-radio = {
      description = "OpenPost Radio, pre-encoded NAS library to YouTube";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      path = [
        pkgs.nodejs_24
        pkgs.ffmpeg
        pkgs.openssh
      ];
      environment = {
        RGO_MUSIC_REVISION = "1fd0b84";
        RGO_MUSIC_STATE = "/var/lib/openpost-radio";
        RGO_MUSIC_BUFFER = "/var/cache/openpost-radio";
        RGO_MUSIC_NAS_HOST = "kraktoos@100.88.5.41";
        RGO_MUSIC_NAS_KNOWN_HOSTS = "/etc/nas-backup/known_hosts";
        NODE_OPTIONS = "--max-old-space-size=64";
      };
      serviceConfig = {
        ExecStart = "${pkgs.nodejs_24}/bin/node /opt/openpost-radio/app/src/stream/relay.js";
        EnvironmentFile = config.sops.secrets.openpost-radio-env.path;
        LoadCredential = "nas-key:${config.sops.secrets.openpost-radio-nas-key.path}";
        User = "openpost-radio";
        Group = "openpost-radio";
        StateDirectory = "openpost-radio";
        CacheDirectory = "openpost-radio";
        StateDirectoryMode = "0700";
        CacheDirectoryMode = "0700";
        Restart = "always";
        RestartSec = "10s";
        MemoryMax = "128M";
        MemorySwapMax = 0;
        CPUQuota = "50%";
        TasksMax = 32;
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        UMask = "0077";
      };
    };
  };
}
