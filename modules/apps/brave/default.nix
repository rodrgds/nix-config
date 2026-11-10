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

  # Brave force-installs these through Chromium's WebAppInstallForceList
  # policy: a real PWA when the site has a manifest, a windowed shortcut
  # otherwise. Plain-HTTP origins are marked trustworthy so their manifests
  # count too (PWAs need a secure context).
  # https://chromeenterprise.google/policies/#WebAppInstallForceList
  webAppUrls = lib.attrValues cfg.webApps;
  policies = lib.optionalAttrs (cfg.webApps != { }) {
    WebAppInstallForceList = lib.mapAttrsToList (name: url: {
      inherit url;
      default_launch_container = "window";
      create_desktop_shortcut = false;
      fallback_app_name = name;
    }) cfg.webApps;
    OverrideSecurityRestrictionsOnInsecureOrigin = map (
      url: lib.head (builtins.match "(http://[^/]+).*" url)
    ) (lib.filter (lib.hasPrefix "http://") webAppUrls);
  };
  darwinPolicyFile = pkgs.writeText "com.brave.Browser.plist" (
    lib.generators.toPlist { escape = true; } policies
  );
  darwinPolicyPath = "/Library/Managed Preferences/com.brave.Browser.plist";
in
{
  options.apps.brave = {
    enable = lib.mkEnableOption "Enable Brave web browser";

    webApps = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        "YouTube Music" = "https://music.youtube.com/";
      };
      description = "Web apps Brave installs as standalone apps, by name and URL.";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.brave ];
        environment.etc."brave/policies/managed/rgo.json" = lib.mkIf (policies != { }) {
          text = builtins.toJSON policies;
        };

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

        # Machine-wide managed preferences are Chromium's policy source on an
        # unenrolled Mac. Brave applies changes on its next policy refresh.
        system.activationScripts.extraActivation.text = lib.mkAfter (
          if policies == { } then
            ''
              rm -f ${lib.escapeShellArg darwinPolicyPath}
            ''
          else
            ''
              if ! cmp -s ${darwinPolicyFile} ${lib.escapeShellArg darwinPolicyPath}; then
                mkdir -p "/Library/Managed Preferences"
                install -m 0644 -o root -g wheel ${darwinPolicyFile} ${lib.escapeShellArg darwinPolicyPath}
                killall cfprefsd 2>/dev/null || true
              fi
            ''
        );

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
