{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.steam;
  inherit (constants) isLinux;
in
{
  options.apps.steam = {
    enable = lib.mkEnableOption "Enable Steam";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        programs.steam = {
          enable = true;
          # Make GameMode's client libraries visible inside Steam Linux Runtime
          # containers. Without this, native games inherit libgamemodeauto but
          # fail to load libgamemode.so after pressure-vessel starts.
          package = pkgs.steam.override {
            extraLibraries = p: [ p.gamemode.lib ];
          };
          remotePlay.openFirewall = true;
          dedicatedServer.openFirewall = true;
        };

        # Keep shader processing from starving steamwebhelper. Steam can update
        # CS2's multi-gigabyte shader cache during startup, and using every CPU
        # thread makes local Steam UI chunks time out while that work is active.
        home-manager.users.${username} = _: {
          home.file.".local/share/Steam/steam_dev.cfg".text = ''
            unShaderBackgroundProcessingThreads 4
            unShaderHighPriorityProcessingThreads 8
          '';
        };
      })
    ]
  );
}
