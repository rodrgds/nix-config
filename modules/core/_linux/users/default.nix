{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.core.users;
in
{
  options.core.users = {
    enable = lib.mkEnableOption "Enable user configuration";
  };

  config = lib.mkIf cfg.enable {
    users.users.${username} = {
      isNormalUser = true;
      description = "Rodrigo Dias";
      extraGroups = [
        "networkmanager"
        "wheel"
        "docker"
        "adbusers"
        "kvm"
        "plugdev"
        "dialout"
      ];
      shell = pkgs.bash;
    };

    services.getty.autologinUser = username;

    # Home-manager base configuration
    home-manager.users.${username} = {
      home.enableNixpkgsReleaseCheck = false;
      home.stateVersion = "25.05";
    };
  };
}
