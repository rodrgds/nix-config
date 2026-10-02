{
  lib,
  config,
  pkgs,
  constants,
  username,
  ...
}:
let
  cfg = config.core.docker;
  inherit (constants) isDarwin isLinux homeDir;
in
{
  options.core.docker = {
    enable = lib.mkEnableOption "Enable Docker";
    desktopMemoryMiB = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = null;
      description = "Docker Desktop VM memory allowance. Applied only while Docker Desktop is stopped.";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        virtualisation.docker = {
          enable = true;
          enableOnBoot = false;
          package = pkgs.docker_29;
        };
      })

      (lib.optionalAttrs isDarwin {
        homebrew.casks = [ "docker-desktop" ];
        home-manager.users.${username} = lib.mkIf (cfg.desktopMemoryMiB != null) (
          { lib, ... }:
          {
            home.activation.dockerDesktopResources = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
              settings_file=${lib.escapeShellArg "${homeDir}/Library/Group Containers/group.com.docker/settings-store.json"}
              desktop_memory_mib=${toString cfg.desktopMemoryMiB}
              docker_settings_jq=${pkgs.jq}/bin/jq
              ${builtins.readFile ./desktop-resources.sh}
            '';
          }
        );
      })
    ]
  );
}
