{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.stripe-cli;
in
{
  options.apps.stripe-cli = {
    enable = lib.mkEnableOption "Enable Stripe CLI";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.stripe-cli ];
  };
}
