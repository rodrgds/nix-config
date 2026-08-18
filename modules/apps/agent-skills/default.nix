{
  config,
  constants,
  lib,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.agent-skills;
  inherit (constants) isDarwin isLinux;

  installDir = ".local/share/npm-global";
  installRoot = "${constants.homeDir}/${installDir}";
  skillsBin = "${installRoot}/bin/skills";

  # All skills live in this repo directory. It is the single source of truth.
  # Edit skills here; the rebuild syncs them to ~/.agents/skills/.
  skillsDir = ./skills;

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

  # Use `update-agent-skills` to pull upstream skill updates into ~/.agents/skills/.
  # Then copy changed files back into the repo skills directory and commit.
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
  options.apps.agent-skills = {
    enable = lib.mkEnableOption "Enable declaratively managed global Agent Skills";
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

          # The repo's skills/ directory is the source of truth.
          # Rebuild syncs it to ~/.agents/skills/.
          home.activation.syncSkills = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            source=${lib.escapeShellArg skillsDir}
            target="$HOME/.agents/skills"
            chmod -R u+w "$target" 2>/dev/null || true
            rm -rf "$target"
            mkdir -p "$target"
            cp -a "$source/". "$target/"
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
