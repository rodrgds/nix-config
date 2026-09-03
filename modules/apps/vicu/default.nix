{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.vicu;
  inherit (constants) homeDir isDarwin isLinux;

  vikunjaUrl = "https://tasks.rgo.pt";
  vicuConfigDir =
    if isDarwin then "${homeDir}/Library/Application Support/Vicu" else "${homeDir}/.config/Vicu";

  coreutils = "${pkgs.coreutils}/bin";
in
{
  options.apps.vicu = {
    enable = lib.mkEnableOption "Vicu desktop task manager (Vikunja client)";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.vicu ];
      })
      {
        home-manager.users.${username} =
          { config, lib, ... }:
          {
            sops.secrets.vicu_api_token = { };

            # The Nix-packaged macOS bundle never lands in a Spotlight-indexed
            # location on its own. Link it into ~/Applications like a manual
            # install; the Developer ID signature stays valid through a symlink.
            home.packages = lib.optionals isDarwin [ pkgs.vicu ];

            home.activation = {
              # Vicu reads its server URL and API token from config.json, with
              # the encrypted auth.json store taking precedence when present.
              # Seed both declaratively via jq, preserving every other key
              # (inbox project, hotkeys, custom lists) the app itself manages.
              # The token travels from the sops secret file to jq via
              # --rawfile, never through the Nix store or process arguments.
              # sops-nix decrypts through an async launchd service, so a new
              # secret may not be on disk yet when this runs. Wait for it
              # instead of skipping (hermes-desktop uses the same pattern).
              vicuConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
                secret="${config.sops.secrets.vicu_api_token.path}"
                configFile="${vicuConfigDir}/config.json"
                for _attempt in {1..30}; do
                  if [ -r "$secret" ]; then
                    break
                  fi
                  sleep 1
                done
                if [ -r "$secret" ]; then
                  ${coreutils}/mkdir -p "${vicuConfigDir}"
                  tmp="$(${coreutils}/mktemp)"
                  if [ -f "$configFile" ] && ${pkgs.jq}/bin/jq -e . "$configFile" >/dev/null 2>&1; then
                    src="$configFile"
                  else
                    echo '{}' > "$tmp.base"
                    src="$tmp.base"
                  fi
                  ${pkgs.jq}/bin/jq --arg url ${lib.escapeShellArg vikunjaUrl} --rawfile token "$secret" '
                    .vikunja_url = $url
                    | .api_token = ($token | sub("\r?\n$"; ""))
                    | .auth_method = "api_token"
                  ' "$src" > "$tmp"
                  if [ ! -f "$configFile" ] || ! ${coreutils}/cmp -s "$tmp" "$configFile"; then
                    ${coreutils}/cat "$tmp" > "$configFile"
                    ${coreutils}/chmod 600 "$configFile"
                    echo "vicu: seeded tasks.rgo.pt account into config.json" >&2
                  fi
                  ${coreutils}/rm -f "$tmp" "$tmp.base"
                else
                  echo "vicu: sops secret was not provisioned within 30 seconds, skipping config seeding" >&2
                fi
              '';
            }
            // lib.optionalAttrs isDarwin {
              vicuInstallMacApp = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
                ${coreutils}/mkdir -p "${homeDir}/Applications"
                ${coreutils}/ln -sfn "${pkgs.vicu}/Applications/Vicu.app" "${homeDir}/Applications/Vicu.app"
              '';
            };
          };
      }
    ]
  );
}
