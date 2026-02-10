# PocketBase multi-instance service
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.vps.pocketbase;
in
{
  options.vps.pocketbase = {
    enable = lib.mkEnableOption "PocketBase service";
    instances = lib.mkOption {
      description = "Map of PocketBase instance names to their ports";
      type = lib.types.attrsOf lib.types.int;
      default = {
        pb = 8090;
      };
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.pocketbase = {
      isSystemUser = true;
      group = "pocketbase";
    };
    users.groups.pocketbase = { };

    systemd.services = lib.mapAttrs' (
      name: port:
      lib.nameValuePair "pocketbase-${name}" {
        description = "PocketBase Instance: ${name}";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          ExecStart = "${pkgs.pocketbase}/bin/pocketbase serve --http 127.0.0.1:${toString port} --dir /var/lib/pocketbase/${name}";
          Restart = "always";
          DynamicUser = true;
          StateDirectory = "pocketbase/${name}";
          CapabilityBoundingSet = "";
          LockPersonality = true;
          NoNewPrivileges = true;
          PrivateTmp = true;
        };
      }
    ) cfg.instances;

    vps.caddy.internalPorts = cfg.instances;

    services.caddy.virtualHosts = lib.mapAttrs' (
      name: port:
      lib.nameValuePair "${name}.rgo.pt" {
        extraConfig = ''
          reverse_proxy 127.0.0.1:${toString port}
        '';
      }
    ) cfg.instances;
  };
}
