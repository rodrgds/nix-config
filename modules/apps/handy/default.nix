{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.handy;
  inherit (constants) isLinux isDarwin homeDir;
in
{
  options.apps.handy = {
    enable = lib.mkEnableOption "Enable Handy";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        # Handy delegates text insertion to wtype in native Wayland sessions.
        environment.systemPackages = [
          pkgs.handy
          pkgs.wtype
        ];
        environment.sessionVariables = {
          WEBKIT_DISABLE_DMABUF_RENDERER = "1";
        };
      })
      (lib.optionalAttrs isDarwin {
        homebrew.casks = [ "handy" ];

        launchd.user.agents.handy = {
          serviceConfig = {
            Label = "com.user.handy";
            # The cask ships only Handy.app and does not link a `handy` CLI
            # into /opt/homebrew/bin, so target the bundled binary directly.
            ProgramArguments = [
              "/Applications/Handy.app/Contents/MacOS/handy"
              "--start-hidden"
              "--no-tray"
            ];
            # Handy daemonizes on startup (the foreground process exits 0 and
            # a detached process keeps running). KeepAlive would therefore
            # respawn it in a loop, reopening the window every few seconds.
            RunAtLoad = true;
            StandardOutPath = "/tmp/handy.log";
            StandardErrorPath = "/tmp/handy.error.log";
          };
        };

        # Handy registers its own macOS login item (SMAppService) whenever
        # `autostart_enabled` is true in its settings store, duplicating the
        # launchd agent above. Pin the flag off so the login item does not
        # come back after we remove it; launchd owns startup instead.
        home-manager.users.${username} =
          { lib, ... }:
          {
            home.activation.handyDisableAutostart = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
              settings="${homeDir}/Library/Application Support/com.pais.handy/settings_store.json"
              if [ -f "$settings" ]; then
                ${pkgs.jq}/bin/jq '(.settings.autostart_enabled) = false' "$settings" > "$settings.tmp"
                mv "$settings.tmp" "$settings"
              fi
            '';
          };
      })
    ]
  );
}
