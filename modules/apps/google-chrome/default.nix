{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.google-chrome;
  inherit (constants) isDarwin isLinux;
in
{
  options.apps.google-chrome = {
    enable = lib.mkEnableOption "Enable Google Chrome";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      # Linux: Install via nixpkgs (only if on Linux)
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.google-chrome ];

        home-manager.users.${username}.xdg.mimeApps = {
          enable = true;
          defaultApplications = lib.genAttrs [
            "application/xhtml+xml"
            "text/html"
            "x-scheme-handler/http"
            "x-scheme-handler/https"
          ] (_: [ "google-chrome.desktop" ]);
        };
      })
      # Darwin: Install via Homebrew (only if on Darwin)
      (lib.optionalAttrs isDarwin {
        homebrew.casks = [ "google-chrome" ];

        home-manager.users.${username} =
          { lib, ... }:
          {
            home.packages = [ pkgs.duti ];

            home.activation.chromeDefaultBrowser = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
              if [ -d "/Applications/Google Chrome.app" ]; then
                ${lib.getExe pkgs.duti} -s com.google.Chrome http
                ${lib.getExe pkgs.duti} -s com.google.Chrome https
                ${lib.getExe pkgs.duti} -s com.google.Chrome public.html all
              fi
            '';
          };
      })
    ]
  );
}
