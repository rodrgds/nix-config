{
  config,
  constants,
  inputs,
  lib,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.hermes-desktop;
  inherit (constants) isDarwin isLinux;
  remoteUrl = "http://rgo-nas:9119";
  secretFile = ../../../secrets/hermes-desktop-secrets.yaml;
  remoteOnlyHermes = pkgs.writeShellScriptBin "hermes" ''
    echo "This Hermes Desktop installation is configured for the rgo-nas remote backend." >&2
    exit 1
  '';
in
{
  options.apps.hermes-desktop.enable = lib.mkEnableOption "Hermes Desktop as a remote-only NAS client";

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isDarwin {
        # Use the signed upstream app on macOS. The launch agent below gives
        # GUI launches the remote backend credentials before first launch.
        homebrew.casks = [ "hermes-desktop" ];
      })

      {
        home-manager.users.${username} =
          { config, lib, ... }:
          let
            tokenPath = config.sops.secrets.hermes_desktop_session_token.path;
            setRemoteEnvironment = pkgs.writeShellApplication {
              name = "set-hermes-desktop-remote-environment";
              text = ''
                if [ ! -r ${lib.escapeShellArg tokenPath} ]; then
                  echo "hermes-desktop: cannot read the remote session token" >&2
                  exit 1
                fi

                token="$(tr -d '\r\n' < ${lib.escapeShellArg tokenPath})"
                if [ -z "$token" ]; then
                  echo "hermes-desktop: the remote session token is empty" >&2
                  exit 1
                fi

                /bin/launchctl setenv HERMES_DESKTOP_REMOTE_URL ${lib.escapeShellArg remoteUrl}
                /bin/launchctl setenv HERMES_DESKTOP_REMOTE_TOKEN "$token"
              '';
            };
          in
          {
            sops.secrets.hermes_desktop_session_token = {
              sopsFile = secretFile;
              mode = "0600";
            };
          }
          // lib.optionalAttrs isLinux {
            # The Nix wrapper reads the token at process start, so it never
            # enters the Nix store and Desktop cannot fall back to a local
            # Hermes runtime.
            home.packages = [
              (inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.desktop.override {
                # Upstream normally bundles the complete local Hermes runtime.
                # This client must fail closed instead of ever falling back to it.
                hermesAgent = remoteOnlyHermes;
                extraEnv.HERMES_DESKTOP_REMOTE_URL = remoteUrl;
                extraRun = [
                  ''
                    if [ ! -r ${lib.escapeShellArg tokenPath} ]; then
                      echo "hermes-desktop: cannot read the remote session token" >&2
                      exit 1
                    fi
                    HERMES_DESKTOP_REMOTE_TOKEN="$(tr -d '\r\n' < ${lib.escapeShellArg tokenPath})"
                    if [ -z "$HERMES_DESKTOP_REMOTE_TOKEN" ]; then
                      echo "hermes-desktop: the remote session token is empty" >&2
                      exit 1
                    fi
                    export HERMES_DESKTOP_REMOTE_TOKEN
                  ''
                ];
              })
            ];
          }
          // lib.optionalAttrs isDarwin {
            # Finder/Spotlight applications do not inherit shell variables.
            # Seed the user launchd environment at activation and every login.
            home.activation.hermesDesktopRemoteEnvironment = lib.hm.dag.entryAfter [ "sops-nix" ] ''
              ${setRemoteEnvironment}/bin/set-hermes-desktop-remote-environment
            '';

            launchd.agents.hermes-desktop-remote-environment = {
              enable = true;
              config = {
                Label = "dev.rgo.hermes-desktop-remote-environment";
                ProgramArguments = [
                  "${setRemoteEnvironment}/bin/set-hermes-desktop-remote-environment"
                ];
                RunAtLoad = true;
                ProcessType = "Background";
              };
            };
          };
      }
    ]
  );
}
