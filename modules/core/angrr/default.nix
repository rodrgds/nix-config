{
  lib,
  config,
  ...
}:
let
  cfg = config.core.angrr;
in
{
  options.core.angrr = {
    enable = lib.mkEnableOption "Enable angrr";
  };

  config = lib.mkIf cfg.enable {
    services.angrr = {
      enable = true;
      period = "5d";
      timer.enable = true;

      settings.temporary-root-policies = {
        devenv = {
          path-regex = "/[.]devenv/";
          period = "5d";
        };
        failed-rebuild = {
          path-regex = "/rgo-[^/]+-failed-rebuild-[^/]+$";
          period = "5d";
        };
      };
    };

    # The scheduled service protects recent development roots before Nix GC.
    # Avoid rescanning every project GC root on each directory activation.
    programs.direnv.angrr.autoUse = false;
  };
}
