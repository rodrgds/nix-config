{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.bumblebee-status;
in
{
  options.apps.bumblebee-status = {
    enable = lib.mkEnableOption "Enable bumblebee-status";
  };

  config = lib.mkIf cfg.enable {
    # The bumblebee-status package is already included in i3 module
    # This module handles the custom stopwatch script

    home-manager.users.${username} = _: {
      home.file.".config/bumblebee-status/modules/stopwatch.py".source = ./bumblebee_stopwatch.py;
    };
  };
}
