# Syncthing - File synchronization
# Uses systemd service on NixOS, launchd on macOS
{
  lib,
  config,
  pkgs,
  username,
  system,
  constants,
  ...
}:
let
  cfg = config.apps.syncthing;
  inherit (constants) isLinux isDarwin homeDir;
in
{
  options.apps.syncthing = {
    enable = lib.mkEnableOption "Enable Syncthing file sync";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        services.syncthing = {
          enable = true;
          user = username;
          dataDir = homeDir;
          configDir = "${homeDir}/.config/syncthing";
          overrideDevices = false;
          overrideFolders = false;
          settings = {
            devices = {
              desktop = {
                id = "CNKRUHN-CHITMG4-ETZSAPP-3IT3JKN-EF4KYRU-KHNVAQZ-YCJWWBW-3GOO2AE";
              };
              phone = {
                id = "I6N5XGX-CTB6R3E-WJ52CAT-ZIWPURA-W37CIKO-RDWCCZU-WC5D7IP-HN7HNAK";
              };
              laptop = {
                id = "PINUALU-HHT6V2C-PQY746A-UXY533A-FYQ3WR5-LRX5G6Q-VNSDUD2-HQEV3AT";
              };
              personalVps = {
                id = "ESNZ7DA-O4PMOHN-BUJG6B7-N7HWP5K-BZYSPDJ-GZNAUCH-UFNIGVA-VZSD7AJ";
              };
            };
          };
        };
      })

      (lib.optionalAttrs isDarwin {
        # Install Syncthing via Homebrew on macOS
        # Note: The Homebrew cask includes a launchd service that can be enabled with:
        #   brew services start syncthing
        # Or manually via: open -a Syncthing
        homebrew.casks = [ "syncthing-app" ];
      })
    ]
  );
}
