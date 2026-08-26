{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.brave;
  inherit (constants) isDarwin isLinux;
in
{
  options.apps.brave.enable = lib.mkEnableOption "Enable Brave web browser";

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.brave ];

        home-manager.users.${username}.xdg.mimeApps = {
          enable = true;
          defaultApplications = lib.genAttrs [
            "application/xhtml+xml"
            "text/html"
            "x-scheme-handler/http"
            "x-scheme-handler/https"
          ] (_: [ "brave-browser.desktop" ]);
        };
      })

      (lib.optionalAttrs isDarwin {
        homebrew.casks = [ "brave-browser" ];

        home-manager.users.${username} =
          { lib, ... }:
          {
            home.packages = [ pkgs.duti ];

            home.activation.braveDefaultBrowser = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
              if [ -d "/Applications/Brave Browser.app" ]; then
                set_brave_handler() {
                  handler="$1"
                  shift

                  if [ "$(${lib.getExe pkgs.duti} -d "$handler" 2>/dev/null || true)" = "com.brave.Browser" ]; then
                    return
                  fi

                  ${lib.getExe pkgs.duti} -s com.brave.Browser "$handler" "$@" || true

                  if [ "$(${lib.getExe pkgs.duti} -d "$handler" 2>/dev/null || true)" != "com.brave.Browser" ]; then
                    echo "warning: macOS refused to set Brave as the handler for $handler; choose Brave under System Settings > Desktop & Dock > Default web browser" >&2
                  fi
                }

                set_brave_handler http
                set_brave_handler https
                set_brave_handler public.html all
              fi
            '';
          };
      })
    ]
  );
}
