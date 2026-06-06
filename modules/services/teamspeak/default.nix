# TeamSpeak 6 voice server
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.vps.teamspeak;

  # TeamSpeak 6 defaults
  voicePort = 9987; # UDP - Voice
  filetransferPort = 30033; # TCP - File transfer
  webqueryPort = 10080; # TCP - HTTP Query default
  sshqueryPort = 10022; # TCP - SSH Query default
in
{
  options.vps.teamspeak = {
    enable = lib.mkEnableOption "TeamSpeak 6 server";

    image = lib.mkOption {
      type = lib.types.str;
      default = "docker.io/teamspeaksystems/teamspeak6-server:latest";
      description = "TeamSpeak 6 server image to run.";
    };

    licenseFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Optional host path to a TeamSpeak 6 licensekey.dat.
        Use a string path to avoid copying the license into the Nix store.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d /var/lib/teamspeak 0755 9987 9987 -"
      "d /var/lib/teamspeak/data 0755 9987 9987 -"
      "d /var/lib/teamspeak/data/logs 0755 9987 9987 -"
      "d /var/lib/teamspeak/data/files 0755 9987 9987 -"
      "d /var/lib/teamspeak/data/crashdumps 0755 9987 9987 -"
    ];

    virtualisation.oci-containers.containers.teamspeak = {
      image = cfg.image;
      autoStart = true;

      environment = {
        TSSERVER_LICENSE_ACCEPTED = "accept";
        TSSERVER_LICENSE_PATH = "/var/tsserver";

        TSSERVER_DEFAULT_PORT = toString voicePort;
        TSSERVER_VOICE_IP = "0.0.0.0";

        TSSERVER_FILE_TRANSFER_PORT = toString filetransferPort;
        TSSERVER_FILE_TRANSFER_IP = "0.0.0.0";

        TSSERVER_QUERY_HTTP_ENABLED = "true";
        TSSERVER_QUERY_HTTP_PORT = toString webqueryPort;

        TSSERVER_QUERY_SSH_ENABLED = "true";
        TSSERVER_QUERY_SSH_PORT = toString sshqueryPort;

        TSSERVER_LOG_PATH = "logs";
      };

      volumes = [
        "/var/lib/teamspeak/data:/var/tsserver"
      ]
      ++ lib.optionals (cfg.licenseFile != null) [
        "${cfg.licenseFile}:/var/tsserver/licensekey.dat:ro"
      ];

      ports = [
        "${toString voicePort}:${toString voicePort}/udp"
        "${toString filetransferPort}:${toString filetransferPort}/tcp"
        "${toString webqueryPort}:${toString webqueryPort}/tcp"
        "${toString sshqueryPort}:${toString sshqueryPort}/tcp"
      ];

      extraOptions = [
        "--network=podman"
        "--pull=always"
      ];
    };

    # Proper weekly updater/restart.
    # This replaces the broken Alpine sidecar scheduler.
    systemd.services.teamspeak-update-restart = {
      description = "Pull latest TeamSpeak 6 image and restart TeamSpeak";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];

      serviceConfig = {
        Type = "oneshot";
      };

      script = ''
        set -euo pipefail
        ${pkgs.podman}/bin/podman pull ${lib.escapeShellArg cfg.image}
        ${config.systemd.package}/bin/systemctl restart podman-teamspeak.service
      '';
    };

    systemd.timers.teamspeak-update-restart = {
      description = "Weekly TeamSpeak 6 image pull and restart";
      wantedBy = [ "timers.target" ];

      timerConfig = {
        OnCalendar = "Sun 04:00";
        Persistent = true;
        Unit = "teamspeak-update-restart.service";
      };
    };

    networking.firewall.allowedTCPPorts = [
      filetransferPort
      webqueryPort
      sshqueryPort
    ];

    networking.firewall.allowedUDPPorts = [
      voicePort
    ];
  };
}
