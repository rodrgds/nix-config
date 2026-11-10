# T3 Code updates several times a week and its sidebar updater moves every
# connected machine in one step, which only works for vendor installs (Nix
# installs must wait for a rebuild). So Nix provides the install and the
# launcher, and T3 Code owns its updates:
# - macOS: the Homebrew cask is marked auto_updates, so brew never touches it.
# - Linux: the official AppImage in ~/.local/share/t3code, which updates itself
#   in place. NixOS runs it through appimage-run via binfmt, which exports the
#   APPIMAGE path the updater rewrites.
{
  config,
  lib,
  pkgs,
  constants,
  username,
  ...
}:
let
  cfg = config.apps.t3-code;
  inherit (constants) isDarwin isLinux homeDir;

  appDir = "${homeDir}/.local/share/t3code";
  appImage = "${appDir}/T3-Code.AppImage";

  # Installs the current stable AppImage once, verified against the
  # electron-updater metadata published with each release.
  bootstrap = pkgs.writeShellApplication {
    name = "t3code-bootstrap";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      gnused
      openssl
    ];
    text = ''
      app=${lib.escapeShellArg appImage}
      [ -x "$app" ] && exit 0

      base=https://github.com/pingdotgg/t3code/releases/latest/download
      dir=$(dirname "$app")
      mkdir -p "$dir"
      fetch() { curl -fsSL --connect-timeout 10 --retry 2 "$@"; }
      meta=$(fetch "$base/latest-linux.yml")
      file=$(sed -n 's/^path: *//p' <<<"$meta")
      sum=$(sed -n 's/^sha512: *//p' <<<"$meta")

      tmp=$(mktemp "$dir/.download.XXXXXX")
      trap 'rm -f "$tmp"' EXIT
      fetch -o "$tmp" "$base/$file"
      if [ "$(openssl dgst -sha512 -binary "$tmp" | base64 -w0)" != "$sum" ]; then
        echo "t3code: checksum mismatch for $file" >&2
        exit 1
      fi
      chmod +x "$tmp"
      mv "$tmp" "$app"
    '';
  };

  desktopEntry = ''
    [Desktop Entry]
    Type=Application
    Name=T3 Code
    Comment=Control coding agents on this machine
    Exec=${appImage} %U
    Icon=utilities-terminal
    Terminal=false
    Categories=Development;
    MimeType=x-scheme-handler/t3code;
  '';
in
{
  options.apps.t3-code = {
    enable = lib.mkEnableOption "T3 Code desktop app";
    autostart = lib.mkEnableOption "opening T3 Code when the desktop session starts";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isDarwin {
        homebrew.casks = [ "t3-code" ];
      })

      (lib.optionalAttrs isLinux {
        programs.appimage = {
          enable = true;
          binfmt = true;
        };

        home-manager.users.${username} =
          { lib, ... }:
          {
            # First install only; failures (offline rebuilds) are retried on
            # the next activation instead of failing the generation.
            home.activation.t3codeBootstrap = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
              ${lib.getExe bootstrap} || echo "t3code: AppImage install failed; retrying on the next rebuild" >&2
            '';

            xdg.dataFile."applications/t3code.desktop".text = desktopEntry;
            xdg.configFile."autostart/t3code.desktop" = lib.mkIf cfg.autostart { text = desktopEntry; };
          };
      })
    ]
  );
}
