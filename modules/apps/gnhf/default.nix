{
  lib,
  config,
  ...
}:
let
  cfg = config.apps.gnhf;
in
{
  options.apps.gnhf = {
    enable = lib.mkEnableOption "Enable gnhf autonomous agent orchestrator";
  };

  config = lib.mkIf cfg.enable {
    apps.javascript-toolchain = {
      enable = true;
      npm.cliPackages.gnhf.package = "gnhf@latest";
    };
  };
}
