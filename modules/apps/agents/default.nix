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

  globalSkillSources = import ./_skill-sources.nix;
  skillAgents = [
    "codex"
    "claude-code"
    "opencode"
    "pi"
  ];

  # The installer owns upstream content and its lockfile outside the checkout.
  ensureSkillsSnippet = lib.concatMapStringsSep "\n" (spec: ''
    ${lib.escapeShellArg toolchain.npm.binDir}/skills add ${lib.escapeShellArg spec.source} \
      --global --yes --full-depth \
      --agent ${lib.escapeShellArgs skillAgents} --skill ${lib.escapeShellArgs spec.skills}
  '') globalSkillSources;

  # Local skills stay editable in the repo, with one link per skill.
  skillsDir = "${constants.homeDir}/.config/home/modules/apps/agents/skills";
  localSkills = builtins.attrNames (
    lib.filterAttrs (_: type: type == "directory") (builtins.readDir ./skills)
  );
  linkSkillsSnippet = ''
    agent_skill_source=${lib.escapeShellArg skillsDir}
    agent_skill_target="$HOME/.agents/skills"
    if [ -L "$agent_skill_target" ]; then
      if [ "$(readlink "$agent_skill_target")" != "$agent_skill_source" ]; then
        echo "agents: unexpected skills directory symlink: $agent_skill_target" >&2
        exit 1
      fi
      rm "$agent_skill_target"
    fi
    for agent_skill_dir in "$agent_skill_target" "$HOME/.claude/skills" "$HOME/.pi/agent/skills"; do
      mkdir -p "$agent_skill_dir"
      for skill_name in ${lib.escapeShellArgs localSkills}; do
        if [ -e "$agent_skill_dir/$skill_name" ] && [ ! -L "$agent_skill_dir/$skill_name" ]; then
          echo "agents: local skill would overwrite an installed directory: $agent_skill_dir/$skill_name" >&2
          exit 1
        fi
        ln -sfn "$agent_skill_source/$skill_name" "$agent_skill_dir/$skill_name"
      done
    done
  '';
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
              ${linkSkillsSnippet}
              ${ensureSkillsSnippet}
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

          home.activation.linkSkills =
            lib.hm.dag.entryAfter
              [
                "writeBoundary"
                "bootstrapJavascriptToolchain"
              ]
              ''
                ${linkSkillsSnippet}
                if [ -x ${lib.escapeShellArg toolchain.npm.binDir}/skills ]; then
                  (
                    # Activation does not inherit the interactive shell's PATH.
                    export PATH="${
                      lib.makeBinPath [
                        toolchain.node.package
                        pkgs.git
                      ]
                    }:$PATH"
                    ${ensureSkillsSnippet}
                  )
                fi
              '';
        }
      ];
  };
}
