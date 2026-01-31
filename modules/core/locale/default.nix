{ lib, config, ... }:
let
  cfg = config.core.locale;
in
{
  options.core.locale = {
    enable = lib.mkEnableOption "Enable locale configuration";
  };

  config = lib.mkIf cfg.enable {
    time.timeZone = "Europe/Lisbon";

    i18n.defaultLocale = "en_US.UTF-8";
    i18n.extraLocaleSettings = {
      LC_ADDRESS = "pt_PT.UTF-8";
      LC_IDENTIFICATION = "pt_PT.UTF-8";
      LC_MEASUREMENT = "pt_PT.UTF-8";
      LC_MONETARY = "pt_PT.UTF-8";
      LC_NAME = "pt_PT.UTF-8";
      LC_NUMERIC = "pt_PT.UTF-8";
      LC_PAPER = "pt_PT.UTF-8";
      LC_TELEPHONE = "pt_PT.UTF-8";
      LC_TIME = "en_US.UTF-8";
    };
  };
}
