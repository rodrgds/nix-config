{
  lib,
  config,
  pkgs,
  constants,
  username,
  ...
}:
let
  cfg = config.apps.screenshot-tools;
  inherit (constants) isLinux isDarwin;
  launcher = "/Users/${username}/.local/libexec/macshot-launch";
  launcherBuildId = builtins.hashString "sha256" (builtins.readFile ./macshot-launch.swift);
in
{
  options.apps.screenshot-tools = {
    enable = lib.mkEnableOption "Enable screenshot annotation and color-picker tools";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.swappy ];

        # Ctrl+C copies through wl-copy, then closes the editor.
        home-manager.users.${username}.xdg.configFile."swappy/config".text = ''
          [Default]
          early_exit=true
        '';
      })
      (lib.optionalAttrs isDarwin {
        homebrew.casks = [
          "pika"
          "macshot"
        ];

        # Pika's URL-triggered picker should leave the selected Hex value on
        # the clipboard without requiring a second shortcut.
        system.defaults.CustomUserPreferences."com.superhighfives.Pika" = {
          copyColorOnPick = true;
          hidePikaWhilePicking = true;
          viewedSplash = true;
        };

        # AeroSpace owns the global screenshot and OCR shortcuts.
        system.defaults.CustomUserPreferences."com.sw33tlie.macshot.macshot" = lib.genAttrs (map (
          slot: "hotkeyDisabled_${toString slot}"
        ) (lib.range 1 12)) (_: true);

        # A login-only prewarm does not cover later exits. Every shortcut must
        # wait for AppKit launch completion before delivering its capture URL.
        home-manager.users.${username} =
          { lib, ... }:
          {
            home.activation.compileMacshotLauncher = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
              stamp="${launcher}.source"
              if [ ! -x ${launcher} ] || [ ! -f "$stamp" ] || [ "$(/bin/cat "$stamp")" != ${lib.escapeShellArg launcherBuildId} ]; then
              (
                set -eu
                /bin/mkdir -p /Users/${username}/.local/libexec
                build_dir="$(/usr/bin/mktemp -d /tmp/macshot-launch.XXXXXX)"
                trap '/bin/rm -rf "$build_dir"' EXIT
                /usr/bin/xcrun swiftc -O ${./macshot-launch.swift} -o "$build_dir/macshot-launch"
                /usr/bin/codesign --force --sign - --identifier dev.rgo.macshot-launch "$build_dir/macshot-launch"
                /bin/mv "$build_dir/macshot-launch" ${launcher}
                printf '%s\n' ${lib.escapeShellArg launcherBuildId} > "$stamp"
              )
              fi
            '';
          };
      })
    ]
  );
}
