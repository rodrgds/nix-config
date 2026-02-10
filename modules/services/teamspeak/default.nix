# TeamSpeak 6 voice server
{
  config,
  lib,
  ...
}:
let
  cfg = config.vps.teamspeak;

  # TeamSpeak 6 ports (defaults from TS6 server docs)
  voicePort = 9987; # UDP - Voice [web:4][web:10]
  filetransferPort = 30033; # TCP - Filetransfer [web:6][web:10]
  webrtcPort = 10081; # TCP - WebQuery / HTTP Query [web:4][web:6]
  serverqueryPort = 10023; # TCP - SSHQuery / ServerQuery SSH [web:4]
in
{
  options.vps.teamspeak = {
    enable = lib.mkEnableOption "TeamSpeak 6 server";
  };

  config = lib.mkIf cfg.enable {
    # Create persistent directories (host side)
    # TS6 container runs as user 'tsserver' (uid 9987), not root
    systemd.tmpfiles.rules = [
      "d /var/lib/teamspeak 0755 9987 9987 -"
      "d /var/lib/teamspeak/data 0755 9987 9987 -"
      "d /var/lib/teamspeak/data/logs 0755 9987 9987 -"
      "d /var/lib/teamspeak/data/files 0755 9987 9987 -"
    ];

    # TeamSpeak 6 server container
    virtualisation.oci-containers.containers.teamspeak = {
      # Official TS6 server image name
      image = "teamspeaksystems/teamspeak6-server:latest"; # [web:7][web:10]

      environment = {
        # Required license flag for TS6 [web:7][web:10]
        TSSERVER_LICENSE_ACCEPTED = "accept";

        # Core server ports & IPs [web:4][web:6]
        TSSERVER_DEFAULT_PORT = toString voicePort;
        TSSERVER_VOICE_IP = "0.0.0.0";

        TSSERVER_FILE_TRANSFER_PORT = toString filetransferPort;
        TSSERVER_FILE_TRANSFER_IP = "0.0.0.0";

        # Enable Web/HTTP query and SSH query [web:4][web:6]
        TSSERVER_QUERY_HTTP_ENABLED = "true";
        TSSERVER_QUERY_HTTP_PORT = toString webrtcPort;

        TSSERVER_QUERY_SSH_ENABLED = "true";
        TSSERVER_QUERY_SSH_PORT = toString serverqueryPort;
      };

      # Correct TS6 data volume:
      # container path is /var/tsserver, as per TS6 Docker docs [web:7][web:9][web:10]
      volumes = [
        "/var/lib/teamspeak/data:/var/tsserver"
      ];

      ports = [
        "${toString voicePort}:${toString voicePort}/udp"
        "${toString filetransferPort}:${toString filetransferPort}/tcp"
        "${toString webrtcPort}:${toString webrtcPort}/tcp"
        "${toString serverqueryPort}:${toString serverqueryPort}/tcp"
      ];

      extraOptions = [
        "--network=podman"
      ];
    };

    # Weekly restart scheduler (still using podman)
    virtualisation.oci-containers.containers.teamspeak-scheduler = {
      image = "docker.io/library/alpine:latest";

      volumes = [
        "/run/podman/podman.sock:/var/run/docker.sock:ro"
      ];

      cmd = [
        "sh"
        "-c"
        "echo '0 4 * * 0 podman restart teamspeak' | crontab - && crond -f"
      ];

      extraOptions = [
        "--network=podman"
      ];
    };

    # Firewall ports
    networking.firewall.allowedTCPPorts = [
      filetransferPort
      webrtcPort
      serverqueryPort
    ];
    networking.firewall.allowedUDPPorts = [
      voicePort
    ];

    # TS6 still uses direct client connections on these ports, no reverse proxy needed. [web:6]
  };
}
