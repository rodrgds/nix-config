{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.darwin.core.system;
  # The login record must hold a path that never changes. A store path breaks
  # every future login once that build is garbage-collected.
  loginShell = "/run/current-system/sw/bin/bash";
  laptopHealth = pkgs.writeShellScriptBin "rgo-laptop-health" (
    ''
      health_sketchybar=${lib.boolToString config.darwin.apps.sketchybar.enable}
      health_borders=${lib.boolToString config.darwin.apps.lightweight-borders.enable}
      health_aerospace=${lib.boolToString config.darwin.apps.aerospace.enable}
      health_keepingyouawake=${lib.boolToString config.darwin.apps.keepingyouawake.enable}
      health_stats=${lib.boolToString config.darwin.apps.stats.enable}
      health_macshot=${lib.boolToString config.apps.screenshot-tools.enable}
      health_brave=${lib.boolToString config.apps.brave.enable}
      health_vicinae=${lib.boolToString config.apps.vicinae.enable}
      health_nix_trust=${lib.boolToString config.core.nix.enable}
      health_nix=${lib.getExe config.nix.package}
      health_allow_signed_app=${lib.boolToString config.networking.applicationFirewall.allowSignedApp}
      health_login_shell=${lib.escapeShellArg loginShell}
    ''
    + builtins.readFile ./laptop-health.sh
  );
in
{
  options.darwin.core.system = {
    enable = lib.mkEnableOption "Enable system";
  };

  config = lib.mkIf cfg.enable {
    networking.applicationFirewall = {
      enable = true;
      enableStealthMode = true;
      blockAllIncoming = false;
      allowSigned = true;
      # Downloaded signatures do not imply permission to listen on the LAN.
      # Built-in software and existing explicit per-app decisions are separate.
      allowSignedApp = false;
    };

    # Keep sudo fast at the laptop and inside long-lived terminal sessions.
    security.pam.services.sudo_local = {
      touchIdAuth = true;
      reattach = true;
    };

    # System-wide macOS settings
    system.defaults = {
      # Dock settings
      dock = {
        autohide = true;
        show-recents = false;
        minimize-to-application = true;
        mru-spaces = false;
        tilesize = 48;
        orientation = "bottom";
      };

      # Finder settings
      finder = {
        AppleShowAllExtensions = true;
        FXEnableExtensionChangeWarning = false;
        _FXShowPosixPathInTitle = true;
        ShowPathbar = true;
        ShowStatusBar = true;
        NewWindowTarget = "Home";
      };

      # Global settings
      NSGlobalDomain = {
        AppleShowAllExtensions = true;
        ApplePressAndHoldEnabled = false;
        KeyRepeat = 2;
        InitialKeyRepeat = 15;
        "com.apple.swipescrolldirection" = true;
        "com.apple.trackpad.scaling" = 1.0;
        AppleInterfaceStyle = "Dark";
        AppleMeasurementUnits = "Centimeters";
        AppleMetricUnits = 1;
        AppleTemperatureUnit = "Celsius";
        NSStatusItemSpacing = 2;
        NSStatusItemSelectionPadding = 2;
      };

      # Trackpad settings
      trackpad = {
        Clicking = true;
        TrackpadThreeFingerDrag = true;
      };

      # Login window
      loginwindow = {
        GuestEnabled = false;
        DisableConsoleAccess = true;
      };

      # Screensaver
      screensaver = {
        askForPassword = true;
        askForPasswordDelay = 0;
      };

      # Mission Control
      spaces = {
        spans-displays = false;
      };

      # Menu bar
      menuExtraClock = {
        Show24Hour = true;
        ShowSeconds = false;
        ShowDayOfWeek = true;
        ShowDate = 1;
      };
    };

    # Keyboard settings
    system.keyboard = {
      enableKeyMapping = true;
      remapCapsLockToControl = false;
    };

    # Primary user for nix-darwin
    system.primaryUser = username;

    # The login shell must stay on the system profile: the path survives
    # nixpkgs updates and the current-system root protects it from collection.
    users.users.${username} = {
      name = username;
      home = "/Users/${username}";
      shell = loginShell;
    };

    # nix-darwin only writes the DSCL record for users in users.knownUsers, so
    # keep the login shell aligned here instead of relying on that mechanism.
    system.activationScripts.extraActivation.text = lib.mkAfter ''
      login_shell=${lib.escapeShellArg loginShell}
      current_shell="$(dscl . -read ${lib.escapeShellArg "/Users/${username}"} UserShell 2>/dev/null | sed -n 's/^UserShell: //p')"
      if [ "$current_shell" != "$login_shell" ]; then
        echo "setting ${username} login shell to $login_shell..." >&2
        dscl . -create ${lib.escapeShellArg "/Users/${username}"} UserShell "$login_shell"
      fi
    '';

    environment.shells = [ loginShell ];
    environment.systemPackages = [
      pkgs.bashInteractive
      laptopHealth
    ];

    # Home-manager state version
    home-manager.users.${username} = {
      home.enableNixpkgsReleaseCheck = false;
      home.stateVersion = "25.05";
    };

    # System state version
    system.stateVersion = 5;
  };
}
