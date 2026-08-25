{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.darwin.core.system;
  laptopHealth = pkgs.writeShellScriptBin "rgo-laptop-health" (builtins.readFile ./laptop-health.sh);
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
      allowSignedApp = true;
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

    # User configuration - set Bash as the default shell
    users.users.${username} = {
      name = username;
      home = "/Users/${username}";
      shell = pkgs.bash;
    };

    # Ensure Bash is in /etc/shells and set as login shell
    environment.shells = [ pkgs.bash ];
    environment.systemPackages = [ laptopHealth ];

    # Home-manager state version
    home-manager.users.${username} = {
      home.enableNixpkgsReleaseCheck = false;
      home.stateVersion = "25.05";
    };

    # System state version
    system.stateVersion = 5;
  };
}
