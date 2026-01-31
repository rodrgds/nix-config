{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.core.syncthing;
in
{
  options.core.syncthing = {
    enable = lib.mkEnableOption "Enable Syncthing";
  };

  config = lib.mkIf cfg.enable {
    services.syncthing = {
      enable = true;
      user = username;
      dataDir = "/home/${username}";
      configDir = "/home/${username}/.config/syncthing";
      overrideDevices = false;
      overrideFolders = false;
      settings = {
        devices = {
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
  };
}
