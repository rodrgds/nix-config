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
  skillsPackagePath = "${installRoot}/lib/node_modules/skills/package.json";

  sourceEntries = lib.mapAttrsToList (source: skills: {
    inherit source skills;
  }) cfg.sources;

  managedSkills = lib.unique (lib.concatLists (lib.attrValues cfg.sources));

  manifest = pkgs.writeText "rgo-agent-skills-manifest.json" (
    builtins.toJSON {
      version = 1;
      agents = cfg.agents;
      sources = cfg.sources;
    }
  );

  shellWords = values: lib.concatStringsSep " " (map lib.escapeShellArg values);

  addCommands = lib.concatMapStringsSep "\n" (entry: ''
    "$skills_bin" add ${lib.escapeShellArg entry.source} \
      --global \
      --agent ${shellWords cfg.agents} \
      --skill ${shellWords entry.skills} \
      --yes
  '') sourceEntries;

  healthChecks = lib.concatMapStringsSep "\n" (skill: ''
    if [ ! -f "$HOME/.agents/skills/${skill}/SKILL.md" ]; then
      needs_reconcile=1
    fi
  '') managedSkills;

  cleanupPiNativeCommands = lib.optionalString cfg.cleanupPiNative (
    lib.concatMapStringsSep "\n" (skill: ''
      rm -rf "$HOME/.pi/agent/skills/${skill}"
    '') managedSkills
  );

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

  reconcileAgentSkills = pkgs.writeShellApplication {
    name = "reconcile-agent-skills";

    runtimeInputs = [
      pkgs.coreutils
      pkgs.git
      pkgs.jq
      pkgs.nodejs
    ];

    text = ''
      skills_bin=${lib.escapeShellArg skillsBin}
      skills_package=${lib.escapeShellArg skillsPackagePath}
      current_manifest=${lib.escapeShellArg "${manifest}"}

      state_dir="$HOME/.local/state/rgo-agent-skills"
      previous_manifest="$state_dir/managed.json"

      mkdir -p \
        "$state_dir" \
        "$HOME/.agents/skills"

      if [ ! -x "$skills_bin" ] || [ ! -f "$skills_package" ]; then
        ${installSkillsCli}/bin/install-skills-cli
      fi

      needs_reconcile=0

      if [ ! -f "$previous_manifest" ] || \
         ! cmp -s "$current_manifest" "$previous_manifest"; then
        needs_reconcile=1
      fi

      ${healthChecks}

      # Pi also discovers ~/.agents/skills. Keep the Nix-managed skills in one
      # shared location and remove stale Pi-native copies that `skills --agent pi`
      # or auto-detection may have created earlier.
      ${cleanupPiNativeCommands}

      if [ "$needs_reconcile" -eq 0 ]; then
        exit 0
      fi

      # Remove only skills previously owned by this module. Manually installed,
      # unrelated skills remain untouched.
      if [ -f "$previous_manifest" ]; then
        while IFS= read -r old_skill; do
          [ -n "$old_skill" ] || continue

          if ! jq -e \
            --arg name "$old_skill" \
            'any(.sources[][]; . == $name)' \
            "$current_manifest" >/dev/null; then
            "$skills_bin" remove \
              --global \
              --agent ${shellWords cfg.agents} \
              --skill "$old_skill" \
              --yes
          fi
        done < <(jq -r '.sources[][]' "$previous_manifest")
      fi

      ${addCommands}

      install -m 0600 \
        "$current_manifest" \
        "$previous_manifest"
    '';
  };

  updateAgentSkills = pkgs.writeShellApplication {
    name = "update-agent-skills";

    runtimeInputs = [
      pkgs.coreutils
      pkgs.git
      pkgs.nodejs
    ];

    text = ''
      ${installSkillsCli}/bin/install-skills-cli
      ${reconcileAgentSkills}/bin/reconcile-agent-skills

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

    agents = lib.mkOption {
      type = with lib.types; nonEmptyListOf str;
      default = [ "zed" ];
      description = ''
        skills.sh agent targets used for the shared global ~/.agents/skills
        install. Pi discovers ~/.agents/skills itself, so do not target `pi`
        here unless you intentionally also want ~/.pi/agent/skills copies.
      '';
    };

    cleanupPiNative = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Remove Nix-managed skill names from ~/.pi/agent/skills so Pi reads the
        shared ~/.agents/skills copies instead of stale Pi-native duplicates.
      '';
    };

    sources = lib.mkOption {
      type = with lib.types; attrsOf (listOf str);

      default = {
        "pbakaus/impeccable" = [
          "impeccable"
        ];

        "dmmulroy/anti-slop" = [
          "install-anti-slop"
        ];

        "mattpocock/skills" = [
          # Engineering: user-invoked
          "ask-matt"
          "grill-with-docs"
          "triage"
          "improve-codebase-architecture"
          "setup-matt-pocock-skills"
          "to-spec"
          "to-tickets"
          "implement"
          "wayfinder"

          # Engineering: model-invoked
          "prototype"
          "diagnosing-bugs"
          "research"
          "tdd"
          "domain-modeling"
          "codebase-design"
          "code-review"
          "resolving-merge-conflicts"
          "wizard"

          # Productivity: user-invoked
          "grill-me"
          "handoff"
          "teach"
          "to-questionnaire"
          "wait-what"

          # Productivity: model-invoked
          "grilling"
          "writing-for-agents"
        ];

        "h0rv/agent-skills" = [
          "devenv"
        ];

        "getpaseo/paseo" = [
          "paseo"
        ];
      };

      description = ''
        skills.sh sources and explicit skill allowlist installed globally into
        ~/.agents/skills.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    apps.nodejs.enable = true;

    home-manager.users.${username} =
      { lib, ... }:
      lib.mkMerge [
        {
          home.packages = [
            reconcileAgentSkills
            updateAgentSkills
          ];

          home.sessionPath = [ "$HOME/${installDir}/bin" ];

          home.activation.reconcileAgentSkills = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            ${reconcileAgentSkills}/bin/reconcile-agent-skills
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
