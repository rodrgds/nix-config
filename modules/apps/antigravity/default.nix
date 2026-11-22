# Antigravity CLI (`agy`) updates itself in ~/.local/bin, so Nix only provides
# the first install, the shared agent instructions and the T3 Code provider.
# Skills reach ~/.gemini/config/skills through the shared skills CLI
# (`antigravity-cli` agent in modules/apps/agents).
{
  config,
  lib,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.antigravity;
  inherit (constants) homeDir;
  agy = "${homeDir}/.local/bin/agy";
  t3Settings = "${homeDir}/.t3/userdata/settings.json";
in
{
  options.apps.antigravity = {
    enable = lib.mkEnableOption "Antigravity CLI (agy)";
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${username} =
      { lib, ... }:
      {
        home.file.".gemini/config/AGENTS.md".source = ../agents/AGENTS.md;

        # First install only; offline rebuilds retry on the next activation.
        home.activation.antigravityBootstrap = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          if [ ! -x ${lib.escapeShellArg agy} ]; then
            ${lib.getExe pkgs.curl} -fsSL --connect-timeout 10 https://antigravity.google/cli/install.sh \
              | PATH="${
                lib.makeBinPath [
                  pkgs.coreutils
                  pkgs.bash
                ]
              }:$PATH" bash -s -- --skip-path --skip-aliases \
              || echo "antigravity: agy install failed; retrying on the next rebuild" >&2
          fi
        '';

        # Registers the provider once; T3 Code owns the file afterwards.
        home.activation.antigravityT3Provider = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          settings=${lib.escapeShellArg t3Settings}
          if [ -f "$settings" ] && ! ${lib.getExe pkgs.jq} -e '.providerInstances.antigravity' "$settings" >/dev/null; then
            tmp=$(mktemp)
            ${lib.getExe pkgs.jq} '.providerInstances.antigravity = {driver: "antigravity", enabled: true, config: {}}' "$settings" > "$tmp" \
              && cat "$tmp" > "$settings"
            rm -f "$tmp"
          fi
        '';
      };
  };
}
