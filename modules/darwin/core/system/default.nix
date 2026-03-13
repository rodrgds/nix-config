{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.darwin.core.system;
in
{
  options.darwin.core.system = {
    enable = lib.mkEnableOption "Enable Darwin system configuration";
  };

  config = lib.mkIf cfg.enable {
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

    # Nix settings
    nix = {
      settings = {
        experimental-features = "nix-command flakes";
      };
      gc = {
        automatic = true;
        interval = {
          Weekday = 0;
          Hour = 2;
          Minute = 0;
        };
        options = "--delete-older-than 7d";
      };
      optimise = {
        automatic = true;
      };
    };

    # User configuration - set Nushell as the default shell
    users.users.${username} = {
      name = username;
      home = "/Users/${username}";
      shell = pkgs.nushell;
    };

    # Ensure Nushell is in /etc/shells and set as login shell
    environment.shells = [ pkgs.nushell ];

    home-manager.backupFileExtension = "hm-bak";

    # Home-manager state version
    home-manager.users.${username} = {
      home.stateVersion = "25.05";
    };

    # System state version
    system.stateVersion = 5;
  };
}
