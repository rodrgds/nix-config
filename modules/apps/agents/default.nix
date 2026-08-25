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
  inherit (constants) isDarwin isLinux;

  installDir = ".local/share/npm-global";
  installRoot = "${constants.homeDir}/${installDir}";
  skillsBin = "${installRoot}/bin/skills";

  # All skills live in this repo directory. It is the single source of truth.
  # Edit skills here; the rebuild creates a symlink at ~/.agents/skills/.
  # The skills CLI writes through the symlink, so `skills add` and `skills update`
  # install directly into the repo. Commit after updating.
  # Use an absolute string path (not a Nix path like ./skills) so the
  # symlink points at the mutable repo, not a read-only /nix/store
  # snapshot that gets GC'd and breaks.
  skillsDir = "${constants.homeDir}/.config/home/modules/apps/agents/skills";

  installSkillsCli = pkgs.writeShellApplication {
    name = "install-skills-cli";

    runtimeInputs = [
      pkgs.coreutils
      pkgs.nodejs
    ];

    text = ''
      install_root=${lib.escapeShellArg installRoot}
      mkdir -p "$install_root"

      npm install \
        --global \
        --prefix "$install_root" \
        --ignore-scripts \
        --no-audit \
        --no-fund \
        skills@latest
    '';
  };

  updateAgentSkills = pkgs.writeShellApplication {
    name = "update-agent-skills";

    runtimeInputs = [
      pkgs.coreutils
      pkgs.nodejs
    ];

    text = ''
      ${installSkillsCli}/bin/install-skills-cli

      exec ${lib.escapeShellArg skillsBin} \
        update \
        --global \
        --yes
    '';
  };
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
    apps.nodejs.enable = true;

    home-manager.users.${username} =
      { lib, ... }:
      lib.mkMerge [
        {
          home.packages = [
            updateAgentSkills
          ];

          home.sessionPath = [ "$HOME/${installDir}/bin" ];

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

        (lib.optionalAttrs isLinux {
          systemd.user.services.update-agent-skills = {
            Unit.Description = "Update skills.sh CLI and global Agent Skills";
            Service = {
              Type = "oneshot";
              ExecStart = "${updateAgentSkills}/bin/update-agent-skills";
              Nice = 10;
              IOSchedulingClass = "idle";
            };
          };

          systemd.user.timers.update-agent-skills = {
            Unit.Description = "Periodically update global Agent Skills";
            Timer = {
              OnBootSec = "25m";
              OnUnitActiveSec = "1d";
              RandomizedDelaySec = "2h";
              Persistent = true;
            };
            Install.WantedBy = [ "timers.target" ];
          };
        })

        (lib.optionalAttrs isDarwin {
          launchd.agents.update-agent-skills = {
            enable = true;
            config = {
              Label = "pt.rgo.update-agent-skills";
              ProgramArguments = [ "${updateAgentSkills}/bin/update-agent-skills" ];
              StartCalendarInterval = lib.hm.darwin.mkCalendarInterval "daily";
              ProcessType = "Background";
              LowPriorityIO = true;
              StandardOutPath = "/tmp/update-agent-skills.log";
              StandardErrorPath = "/tmp/update-agent-skills.err";
              EnvironmentVariables = {
                HOME = constants.homeDir;
              };
            };
          };
        })
      ];
  };
}
