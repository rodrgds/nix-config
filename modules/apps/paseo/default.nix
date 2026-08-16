{
  lib,
  config,
  pkgs,
  inputs,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.paseo;
  inherit (constants) isDarwin isLinux;
  paseoPkgs = inputs.paseo.packages.${pkgs.stdenv.hostPlatform.system};

  # Tailscale CLI locations. On NixOS it comes from nixpkgs; on macOS it ships
  # inside the Homebrew Tailscale app bundle.
  tailscaleCandidates =
    if isLinux then
      [ "${pkgs.tailscale}/bin/tailscale" ]
    else
      [
        "/Applications/Tailscale.app/Contents/MacOS/Tailscale"
        "/opt/homebrew/bin/tailscale"
        "/usr/local/bin/tailscale"
      ];

  # Surgically set daemon.listen to this machine's Tailscale IP, preserving
  # every other key Paseo manages at runtime (relay, providers, password hash).
  setPaseoTailscaleListen = pkgs.writeShellApplication {
    name = "set-paseo-tailscale-listen";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
    ];
    # The `$schema` JSON key is deliberately literal, not shell expansion, so
    # suppress SC2016 ("expressions don't expand in single quotes").
    excludeShellChecks = [ "SC2016" ];
    text = ''
      tailscale_bin=""
      for candidate in ${lib.escapeShellArgs tailscaleCandidates}; do
        if [ -x "$candidate" ]; then
          tailscale_bin="$candidate"
          break
        fi
      done

      if [ -z "$tailscale_bin" ]; then
        echo "paseo: tailscale CLI not found; skipping daemon.listen" >&2
        exit 0
      fi

      ip="$("$tailscale_bin" ip -4 2>/dev/null | head -n1)"
      if [ -z "$ip" ]; then
        echo "paseo: tailscale has no IPv4 address yet; skipping daemon.listen" >&2
        exit 0
      fi

      listen="$ip:${toString cfg.tailscale.port}"
      cfg_file="$HOME/.paseo/config.json"

      if [ -f "$cfg_file" ]; then
        current="$(jq -r '.daemon.listen // empty' "$cfg_file" 2>/dev/null)"
      else
        current=""
        mkdir -p "$(dirname "$cfg_file")"
      fi

      if [ "$current" = "$listen" ]; then
        exit 0
      fi

      base='{"$schema":"https://paseo.sh/schemas/paseo.config.v1.json","version":1}'
      if [ -f "$cfg_file" ]; then
        base="$(cat "$cfg_file")"
      fi

      umask 077
      printf '%s' "$base" | jq --arg listen "$listen" '.daemon.listen = $listen' > "$cfg_file.tmp"
      mv -f "$cfg_file.tmp" "$cfg_file"
      echo "paseo: set daemon.listen to $listen"
    '';
  };
in
{
  options.apps.paseo = {
    enable = lib.mkEnableOption "Enable Paseo";

    desktop = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install the Paseo desktop app.";
    };

    cli = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install the Paseo CLI and daemon (`paseo`, `paseo-server`).";
    };

    tailscale = {
      enable = lib.mkEnableOption ''
        Listen on this machine's Tailscale IP so other devices on the tailnet can
        connect directly (no relay). Sets daemon.listen in ~/.paseo/config.json
        at activation time.
      '';

      port = lib.mkOption {
        type = lib.types.port;
        default = 6767;
        description = "Port the Paseo daemon listens on.";
      };
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        # The upstream flake tracks nixpkgs-unstable, which this repo does not
        # follow, so pull the packages from Paseo's own flake output instead of
        # the pinned nixpkgs. Its buildNpmPackage derivations already support
        # x86_64-linux and aarch64-linux.
        environment.systemPackages =
          lib.optionals cfg.cli [ paseoPkgs.default ] ++ lib.optionals cfg.desktop [ paseoPkgs.desktop ];
      })

      (lib.optionalAttrs isDarwin {
        # The notarized macOS desktop app ships as a Homebrew cask, which also
        # links the bundled `paseo` CLI. The upstream Nix desktop derivation
        # is a from-source Electron build and is intentionally not used here.
        homebrew.casks = lib.optionals cfg.desktop [ "paseo" ];
      })

      {
        home-manager.users.${username} =
          { lib, ... }:
          lib.mkIf cfg.tailscale.enable {
            # daemon.listen is a startup setting, so the value applies the next
            # time Paseo starts its daemon (desktop app launch, app update, or
            # `paseo daemon restart`). The desktop app owns the daemon
            # lifecycle, so this only writes the desired state to disk.
            home.activation.paseoTailscaleListen = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
              ${setPaseoTailscaleListen}/bin/set-paseo-tailscale-listen
            '';
          };
      }
    ]
  );
}
