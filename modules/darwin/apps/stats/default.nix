{
  lib,
  config,
  username,
  constants,
  ...
}:
let
  cfg = config.darwin.apps.stats;
in
{
  options.darwin.apps.stats.enable =
    lib.mkEnableOption "lightweight CPU, RAM, and disk menu bar metrics";

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = constants.isDarwin;
        message = "darwin.apps.stats is only supported on macOS";
      }
    ];

    homebrew.casks = [ "stats" ];

    system.defaults.CustomUserPreferences."eu.exelban.Stats" = {
      # Stats clears all preferences on first launch unless a prior version is
      # present. Any valid older version preserves these managed defaults.
      version = "0.0.0";
      setupProcess = true;
      runAtLoginInitialized = true;
      "update-interval" = "Never";
      dockIcon = false;
      CombinedModules = false;

      CPU_state = true;
      CPU_widget = "mini";
      CPU_updateInterval = 2;
      CPU_processes = 0;
      CPU_mini_label = true;
      CPU_mini_color = "monochrome";

      RAM_state = true;
      RAM_widget = "mini";
      RAM_updateInterval = 5;
      RAM_processes = 0;
      RAM_mini_label = true;
      RAM_mini_color = "monochrome";

      Disk_state = true;
      Disk_widget = "mini";
      Disk_updateInterval = 30;
      Disk_processes = 0;
      Disk_SMART = false;
      Disk_ATASMART = false;
      SSD_mini_label = true;
      SSD_mini_color = "monochrome";

      GPU_state = false;
      Sensors_state = false;
      Network_state = false;
      Battery_state = false;
      Bluetooth_state = false;
      Clock_state = false;
      Remote_state = false;
    };

    # Keep startup under Home Manager instead of adding Stats' own login item.
    home-manager.users.${username}.launchd.agents.stats = {
      enable = true;
      config = {
        ProgramArguments = [ "/Applications/Stats.app/Contents/MacOS/Stats" ];
        RunAtLoad = true;
        ProcessType = "Interactive";
      };
    };
  };
}
