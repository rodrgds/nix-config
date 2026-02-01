{
  lib,
  config,
  pkgs,
  inputs,
  username,
  ...
}:
let
  cfg = config.apps.opencode-web;
  isLinux = pkgs.stdenv.isLinux;

  # Only define systemd service config on Linux
  systemdConfig = lib.optionalAttrs isLinux {
    services.opencode-web = {
      description = "Opencode Web Server";
      after = [
        "network.target"
        "tailscaled.service"
      ];
      wants = [ "tailscaled.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = username;
        Group = "users";
        WorkingDirectory = "/home/${username}";
        ExecStart = "${pkgs.opencode}/bin/opencode web --hostname 0.0.0.0 --port 4096";
        Restart = "always";
        RestartSec = 5;
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = false;
        ReadWritePaths = [ "/home/${username}" ];
      };

      environment = {
        HOME = "/home/${username}";
        USER = username;
      };
    };
  };
in
{
  options.apps.opencode-web = {
    enable = lib.mkEnableOption "Enable Opencode Web Server";
  };

  # Only enable on Linux
  config = lib.mkIf (cfg.enable && isLinux) {
    systemd = systemdConfig;
  };
}
