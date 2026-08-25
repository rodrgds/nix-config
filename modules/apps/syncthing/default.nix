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
    enable = lib.mkEnableOption "Enable Syncthing";
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
          # Forget tombstone entries for deleted files after 6 months instead of
          # the default 15: deletions still propagate reliably across the few
          # weeks a device may be offline, without a multi-GB index database.
          extraFlags = [ "--db-delete-retention-interval=4368h" ];
          settings = {
            devices = {
              rgo-desktop = {
                id = "CNKRUHN-CHITMG4-ETZSAPP-3IT3JKN-EF4KYRU-KHNVAQZ-YCJWWBW-3GOO2AE";
              };
              rgo-phone = {
                id = "I6N5XGX-CTB6R3E-WJ52CAT-ZIWPURA-W37CIKO-RDWCCZU-WC5D7IP-HN7HNAK";
              };
              rgo-laptop = {
                id = "ZEVRZIA-4O22UC5-5XPMEAD-HGW3WEZ-F7J6ZTU-USJCCNC-WAB72VT-QIOL6QV";
              };
            };
          };
        };

        # During a switch, both changed units can otherwise be queued
        # independently and syncthing-init's Requisite check may run before
        # syncthing has become active. The NixOS module already supplies the
        # matching After= ordering.
        systemd.services.syncthing-init.requires = [ "syncthing.service" ];
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
