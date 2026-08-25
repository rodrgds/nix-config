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
  toolchain = config.apps.javascript-toolchain;
  paseoPkgs = inputs.paseo.packages.${pkgs.stdenv.hostPlatform.system};

  # Declarative base config. daemon.listen is not included here because it
  # depends on the machine's Tailscale IP, which the activation script sets
  # at runtime.
  baseConfig = {
    "$schema" = "https://paseo.sh/schemas/paseo.config.v1.json";
    version = 1;
    daemon = {
      relay.enabled = false;
      enableTerminalAgentHooks = false;
      appendSystemPrompt = "You are running inside Paseo, a desktop/mobile app that launches and supervises agent CLIs. Your daemon config lives at ~/.paseo/config.json. The Nix module that manages Paseo installation and Tailscale listen address is at modules/apps/paseo/default.nix in the home-config repo.";
    };
    worktrees.root = "~/dev/worktrees";
    features = {
      dictation.enabled = false;
      voiceMode.enabled = false;
      webUi.enabled = false;
    };
    # Pin provider binaries so the daemon can find them even when its spawned
    # shell does not inherit the user's full login PATH (common on NixOS with
    # Electron-launched daemons). The paths come from home.sessionPath entries
    # in the corresponding app modules.
    #
    # pi and codex are `#!/usr/bin/env node` scripts. The Paseo daemon runs
    # with a minimal PATH (/usr/bin:/bin:/usr/sbin:/sbin) so `env node`
    # fails with 127. Invoke via the Nix-managed node explicitly and inject a
    # PATH that covers internal `spawn("node", ...)` calls (e.g. pi's
    # rpc-client.js).
    agents.providers = {
      pi = {
        command = [
          toolchain.node.binPath
          "${toolchain.npm.binDir}/pi"
        ];
        env.PATH = "${toolchain.node.binDir}:${toolchain.npm.binDir}:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin";
      };
      codex = {
        command = [
          toolchain.node.binPath
          "${toolchain.npm.binDir}/codex"
        ];
        env.PATH = "${toolchain.node.binDir}:${toolchain.npm.binDir}:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin";
      };
      claude.command = [ "${toolchain.npm.binDir}/claude" ];
      opencode.command = [ "${toolchain.npm.binDir}/opencode" ];
    };
  };

  baseConfigFile = pkgs.writeText "paseo-base-config.json" (builtins.toJSON baseConfig);

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

  # Write the Nix-managed base config and merge daemon.listen from Tailscale.
  # Preserves any keys the user added at runtime while ensuring Nix-owned
  # defaults stay in place.
  setPaseoTailscaleListen = pkgs.writeShellApplication {
    name = "set-paseo-tailscale-listen";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
    ];
    excludeShellChecks = [
      "SC2016"
      # On Linux tailscaleCandidates is a single path, so this loop runs once.
      "SC2043"
    ];
    text = ''
            cfg_file="$HOME/.paseo/config.json"
            mkdir -p "$(dirname "$cfg_file")"

            # If no config exists yet, write the Nix-managed base.
            if [ ! -f "$cfg_file" ]; then
              umask 077
              cp ${lib.escapeShellArg baseConfigFile} "$cfg_file"
            fi

            # Merge Nix-managed base keys on top of the existing config. Runtime-
            # added keys survive; Nix-owned keys are updated on rebuild.
            merged="$(jq -s '.[0] * .[1]' "$cfg_file" ${lib.escapeShellArg baseConfigFile})"
            umask 077
            printf '%s\n' "$merged" > "$cfg_file.tmp"
            mv -f "$cfg_file.tmp" "$cfg_file"

      ${lib.optionalString cfg.tailscale.enable ''
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
        current="$(jq -r '.daemon.listen // empty' "$cfg_file" 2>/dev/null)"

        if [ "$current" = "$listen" ]; then
          exit 0
        fi

        jq --arg listen "$listen" '.daemon.listen = $listen' "$cfg_file" > "$cfg_file.tmp"
        mv -f "$cfg_file.tmp" "$cfg_file"
        echo "paseo: set daemon.listen to $listen"
      ''}
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
          {
            # Write the Nix-managed base config and, when Tailscale is enabled,
            # merge daemon.listen with the machine's Tailscale IP. The desktop
            # app owns the daemon lifecycle; activation only writes desired state
            # to disk.
            home.activation.paseoConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
              ${setPaseoTailscaleListen}/bin/set-paseo-tailscale-listen
            '';
          };
      }
    ]
  );
}
