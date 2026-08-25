{
  config,
  constants,
  lib,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.agents;
  toolchain = config.apps.javascript-toolchain;

  # All skills live in this repo directory. It is the single source of truth.
  # Edit skills here; the rebuild creates a symlink at ~/.agents/skills/.
  # The skills CLI writes through the symlink, so `skills add` and `skills update`
  # install directly into the repo. Commit after updating.
  # Use an absolute string path (not a Nix path like ./skills) so the
  # symlink points at the mutable repo, not a read-only /nix/store
  # snapshot that gets GC'd and breaks.
  skillsDir = "${constants.homeDir}/.config/home/modules/apps/agents/skills";
in
{
  imports = [
    (lib.mkAliasOptionModule
      [
        "apps"
        "agent-skills"
        "enable"
      ]
      [
        "apps"
        "agents"
        "enable"
      ]
    )
  ];

  options.apps.agents = {
    enable = lib.mkEnableOption "Enable declaratively managed global Agent Skills and AGENTS.md";
  };

  config = lib.mkIf cfg.enable {
    apps.javascript-toolchain = {
      enable = true;
      npm.cliPackages.skills = {
        package = "skills@latest";
        postUpdate = [
          ''
            if [ -x ${lib.escapeShellArg toolchain.npm.binDir}/skills ]; then
              ${lib.escapeShellArg toolchain.npm.binDir}/skills update --global --yes
            fi
          ''
        ];
      };
    };

    home-manager.users.${username} =
      { lib, ... }:
      lib.mkMerge [
        {
          # Global AGENTS.md - single source of truth for all agents.
          # Deployed to every harness so instructions stay consistent
          # regardless of which CLI is driving the session.
          home.file.".pi/agent/AGENTS.md".source = ./AGENTS.md;
          home.file.".codex/AGENTS.md".source = ./AGENTS.md;
          home.file.".claude/CLAUDE.md".source = ./AGENTS.md;
          home.file.".claude/AGENTS.md".source = ./AGENTS.md;
          xdg.configFile."opencode/AGENTS.md".source = ./AGENTS.md;

          # Symlink ~/.agents/skills → repo skills directory (mutable, not /nix/store).
          # Single source of truth. Skills CLI writes through the symlink.
          home.activation.linkSkills = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            source=${lib.escapeShellArg skillsDir}
            target="$HOME/.agents/skills"
            if [ -d "$target" ] && [ ! -L "$target" ]; then
              chmod -R u+w "$target" 2>/dev/null || true
              rm -rf "$target"
            fi
            mkdir -p "$(dirname "$target")"
            ln -sfn "$source" "$target"
          '';
        }
      ];
  };
}
