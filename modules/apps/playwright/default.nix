{
  lib,
  config,
  pkgs,
  constants,
  ...
}:
let
  cfg = config.apps.playwright;
  inherit (constants) isLinux;
in
{
  options.apps.playwright = {
    enable = lib.mkEnableOption "Enable Playwright browser test support";

    browserPackage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.chromium;
      description = "Chromium package used by Playwright test configurations.";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.optionalAttrs isLinux {
      environment.systemPackages = [ cfg.browserPackage ];
      environment.sessionVariables = {
        PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH = "${cfg.browserPackage}/bin/chromium";
        PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
      };
    }
  );
}
