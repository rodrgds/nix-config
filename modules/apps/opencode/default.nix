{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.opencode;
  inherit (constants) isDarwin isLinux;
  toolchain = config.apps.javascript-toolchain;
  nineRouterCatalog = import ../../shared/9router.nix;
  # The skills CLI owns upstream installs; local skills are linked here by Nix.
  skillsDir = "${constants.homeDir}/.agents/skills";
  # One local package entry resolves the Hindsight OpenCode V2 integration.
  # The shared toolchain below owns its installation.
  hindsightPluginPath = "${toolchain.npm.installRoot}/lib/node_modules/@vectorize-io/hindsight-coding-agents";
  opencodeSkills = lib.mapAttrs' (
    name: _:
    lib.nameValuePair "opencode/skills/${lib.removeSuffix ".md" name}/SKILL.md" {
      source = ./skills + "/${name}";
    }
  ) (lib.attrsets.filterAttrs (_: type: type == "regular") (builtins.readDir ./skills));
in
{
  options.apps.opencode = {
    enable = lib.mkEnableOption "Enable Opencode";
    nineRouter = {
      baseURL = lib.mkOption {
        type = lib.types.str;
        default = "http://rgo-nas:20128/v1";
        description = "9Router OpenAI-compatible API base URL.";
      };
    };

    web = {
      enable = lib.mkEnableOption "Enable Opencode web";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        apps.javascript-toolchain = {
          enable = true;
          # V2 ships as @opencode/cli; opencode-ai is the retired V1 package.
          # Both provide the `opencode` binary, so uninstall V1 first.
          npm.cliPackages.opencode = {
            package = "@opencode/cli@latest";
            retiredPackages = [ "opencode-ai" ];
          };
          # Hindsight memory plugin runtime (v2 entry resolves the package
          # dir through its index.js). Library package: no binaries, but a
          # bootstrap file so a missing install still triggers an update.
          npm.cliPackages.hindsight-coding-agents = {
            package = "@vectorize-io/hindsight-coding-agents@latest";
            binaries = [ ];
            bootstrapFiles = [
              "lib/node_modules/@vectorize-io/hindsight-coding-agents/package.json"
            ];
            # Upstream 0.7.0 registers its companion skill without the
            # `path` key opencode v2's skill schema requires, so the whole
            # plugin gets disabled (skill.transform failure). Supply the
            # packaged SKILL.md path until upstream fixes it. Guarded by a
            # marker comment so re-runs are no-ops; remove when upstream
            # ships the fix.
            postUpdate = [
              ''
                skill_runtime="$install_root/lib/node_modules/@vectorize-io/hindsight-coding-agents/dist/opencode2.js"
                if [ -f "$skill_runtime" ] && ! grep -q 'nix: opencode v2 Info.path workaround' "$skill_runtime"; then
                  sed -i -e 's/location: srcDir,/location: srcDir, path: join14(srcDir, "SKILL.md"), \/\* nix: opencode v2 Info.path workaround \*\//g' "$skill_runtime" || true
                fi
              ''
            ];
          };
        };

        home-manager.users.${username} =
          { config, lib, ... }:
          let
            nineRouterApiKeyPath = config.sops.secrets.nine_router_api_key.path;
            opencodeGoApiKeyPath = config.sops.secrets.opencode_go_api_key.path;
            exaApiKeyPath = config.sops.secrets.exa_api_key.path;
            hindsightApiTokenPath = config.sops.secrets.hindsight_api_token.path;

            opencodeConfig = {
              "$schema" = "https://opencode.ai/config.json";
              update = "auto";
              model = "nine_router/good";
              # Native websearch (V2): Exa key comes from EXA_API_KEY,
              # exported from the sops secret in shell init below.
              websearch = {
                provider = "exa";
              };
              # Hindsight explicit memory tools; automatic ingestion is disabled.
              # The shared bank is managed centrally. Points at the
              # self-hosted server; bank and tags below live in
              # ~/.hindsight/coding-agent.json, token in HINDSIGHT_API_TOKEN.
              plugins = [ hindsightPluginPath ];
              # Global agent skills, same set Pi uses.
              skills = [ skillsDir ];
              providers = {
                nine_router = {
                  package = "@opencode/ai/providers/openai-compatible";
                  name = "My 9Router (NAS)";
                  settings = {
                    baseURL = cfg.nineRouter.baseURL;
                    apiKey = "{env:NINE_ROUTER_API_KEY}";
                  };
                  models = builtins.listToAttrs (
                    map (m: {
                      name = m.alias;
                      value = {
                        name = m.displayName;
                      };
                    }) nineRouterCatalog.models
                  );
                };
                opencode = {
                  package = "@opencode/ai/providers/openai-compatible";
                  name = "Opencode Zen";
                  settings = {
                    baseURL = "https://opencode.ai/zen/v1";
                    apiKey = "{env:OPENCODE_GO_API_KEY}";
                  };
                  # Use the live built-in catalog, not retired preview IDs.
                };
                opencode-go = {
                  package = "@opencode/ai/providers/openai-compatible";
                  name = "Opencode Go";
                  settings = {
                    baseURL = "https://opencode.ai/zen/go/v1";
                    apiKey = "{env:OPENCODE_GO_API_KEY}";
                  };
                };
              };
              # Executor aggregates the integrations (exa, context7, github,
              # and hindsight tools). Uses OAuth: run
              # `opencode mcp auth executor` once per machine. Memory itself
              # is the Hindsight plugin above, not an MCP server.
              mcp = {
                servers = {
                  executor = {
                    type = "remote";
                    url = "https://executor.sh/rodrigo-dias/mcp";
                  };
                };
              };
            };
          in
          {
            sops.secrets = {
              nine_router_api_key = { };
              exa_api_key = { };
              opencode_go_api_key = { };
              hindsight_api_token.sopsFile = ../../../secrets/hindsight-secrets.yaml;
            };

            # Do not enable HM's V1-oriented module: it installs a second CLI
            # that rejects the V2 config when selected by PATH or a shell hash.
            # Keep the profile entry point, but route it to the shared npm owner.
            home.packages = [
              (pkgs.writeShellScriptBin "opencode" ''
                exec ${lib.escapeShellArg "${toolchain.npm.binDir}/opencode"} "$@"
              '')
            ];

            # V2 owns this mutable client file. Seed our theme only on first
            # use; later rebuilds must preserve preferences changed in the UI.
            home.activation.seedOpenCodeCliConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
              cli_config=${lib.escapeShellArg "${config.xdg.configHome}/opencode/cli.json"}
              if [ ! -e "$cli_config" ]; then
                ${pkgs.coreutils}/bin/install -Dm600 ${
                  pkgs.writeText "opencode-cli-defaults.json" (builtins.toJSON { theme.name = "flexoki"; })
                } "$cli_config"
              fi
            '';

            programs.bash.initExtra = lib.mkAfter ''
              if [ -z "''${NINE_ROUTER_API_KEY:-}" ] && [ -r "${nineRouterApiKeyPath}" ]; then
                export NINE_ROUTER_API_KEY="$(tr -d '\n' < "${nineRouterApiKeyPath}")"
              fi
              if [ -z "''${OPENCODE_GO_API_KEY:-}" ] && [ -r "${opencodeGoApiKeyPath}" ]; then
                export OPENCODE_GO_API_KEY="$(tr -d '\n' < "${opencodeGoApiKeyPath}")"
              fi
              if [ -z "''${EXA_API_KEY:-}" ] && [ -r "${exaApiKeyPath}" ]; then
                export EXA_API_KEY="$(tr -d '\n' < "${exaApiKeyPath}")"
              fi
              if [ -z "''${HINDSIGHT_API_TOKEN:-}" ] && [ -r "${hindsightApiTokenPath}" ]; then
                export HINDSIGHT_API_TOKEN="$(tr -d '\n' < "${hindsightApiTokenPath}")"
              fi
            '';

            programs.zsh.envExtra = lib.mkAfter ''
              if [ -z "''${NINE_ROUTER_API_KEY:-}" ] && [ -r "${nineRouterApiKeyPath}" ]; then
                export NINE_ROUTER_API_KEY="$(tr -d '\n' < "${nineRouterApiKeyPath}")"
              fi
              if [ -z "''${OPENCODE_GO_API_KEY:-}" ] && [ -r "${opencodeGoApiKeyPath}" ]; then
                export OPENCODE_GO_API_KEY="$(tr -d '\n' < "${opencodeGoApiKeyPath}")"
              fi
              if [ -z "''${EXA_API_KEY:-}" ] && [ -r "${exaApiKeyPath}" ]; then
                export EXA_API_KEY="$(tr -d '\n' < "${exaApiKeyPath}")"
              fi
              if [ -z "''${HINDSIGHT_API_TOKEN:-}" ] && [ -r "${hindsightApiTokenPath}" ]; then
                export HINDSIGHT_API_TOKEN="$(tr -d '\n' < "${hindsightApiTokenPath}")"
              fi
            '';

            xdg.configFile =
              opencodeSkills
              // lib.optionalAttrs isLinux {
                "opencode/opencode.json".source =
                  config.lib.file.mkOutOfStoreSymlink
                    config.sops.templates."opencode-config".path;
              }
              // lib.optionalAttrs isDarwin {
                "opencode/opencode.json".text = builtins.toJSON opencodeConfig;
              }
              // {
                "opencode/commands/release.md".text = ''
                  # Release Command

                  Create a new release with conventional commits, tag, and GitHub release.

                  ## Steps

                  1. Run `git status` and `git diff --stat` to see all uncommitted changes
                  2. Run `git log --oneline -10` to see recent commit history
                  3. Run `git tag -l --sort=-v:refname | head -3` to find the latest tag
                  4. If there are uncommitted changes, group them logically and commit using conventional commits:
                     - Review diffs with `git diff <files>`
                     - Stage related files: `git add <files>`
                     - Commit: `git commit -m "type(scope): description\n\nBody"`
                     - Types: feat, fix, chore, docs, refactor, test, ci
                  5. Run `git push` to push all commits
                  6. Determine next version: increment patch from last tag (or minor/major if warranted)
                  7. Create annotated tag: `git tag -a v<version> -m "Release v<version>\n\n## Changes\n- ..."`
                  8. Push tag: `git push origin v<version>`
                  9. Create GitHub release: `gh release create v<version> --title "v<version>" --notes "..."`

                  ## Rules

                  - Group related changes into single commits
                  - Always push commits before tagging
                  - If no uncommitted changes, ask user what version to release
                  - Use `--generate-notes` flag for auto-generated release notes from commits OR, if you prefer, write custom release notes in the tag message body with all relevant changes listed since the last release.
                  - Never use @ in release notes (GitHub interprets as user mentions)
                '';
              };

            # Hindsight plugin config (single JSON file per upstream).
            # apiToken is deliberately absent: the file wins where it sets
            # a value, so the token stays in HINDSIGHT_API_TOKEN from shell
            # init below instead of landing in the Nix store. bankId rodrigo
            # shares Pi's bank; retains carry the per-repo project tag.
            # (`source:` tags are server-reserved; attribution is stamped
            # by the integration itself.) autoUpdate is pinned off;
            # rebuilds move the runtime forward.
            home.file.".hindsight/coding-agent.json".text = builtins.toJSON {
              apiUrl = "http://rgo-nas:8888";
              bankId = "rodrigo";
              retainTags = [ "project:{gitProject}" ];
              manageBankConfig = false;
              retainSessions = false;
              autoSeed = false;
              gitIngest = "none";
              codebaseSurvey = false;
              autoInject = "none";
              pageTriggerType = "manual";
              pages = {
                "Component map" = false;
                "Core concepts" = false;
                "Conventions and patterns" = false;
                "Key decisions and rationale" = false;
                "Initiatives and enhancements" = false;
              };
              recallOptions = {
                types = [ "observation" ];
                budget = "low";
                max_tokens = 600;
              };
              toolGuideExtra = "This is Rodrigo's shared personal and project memory, not this repository alone. Search only the current project's context. Save durable decisions explicitly; verify current code and task state in their canonical systems.";
              autoUpdate = false;
            };
          }
          // lib.optionalAttrs isLinux {
            sops.templates."opencode-config" = {
              content = builtins.toJSON opencodeConfig;
            };
          };
      }
      # (lib.optionalAttrs isLinux {
      #   environment.systemPackages = [ pkgs.unstable.opencode-desktop ];
      # })
      # (lib.optionalAttrs isDarwin {
      #   homebrew.casks = [ "opencode-desktop" ];
      # })
      # (lib.optionalAttrs isLinux (
      #   lib.mkIf cfg.web.enable {
      #     systemd.services.opencode-web = {
      #       description = "Opencode Web Server";
      #       after = [
      #         "network.target"
      #         "tailscaled.service"
      #       ];
      #       wants = [ "tailscaled.service" ];
      #       wantedBy = [ "multi-user.target" ];

      #       serviceConfig = {
      #         Type = "simple";
      #         User = username;
      #         Group = "users";
      #         WorkingDirectory = "/home/${username}";
      #         ExecStart = "${toolchain.npm.binDir}/opencode serve --hostname 0.0.0.0 --port 4096";
      #         Restart = "always";
      #         RestartSec = 5;
      #         NoNewPrivileges = true;
      #         PrivateTmp = true;
      #         ProtectSystem = "strict";
      #         ProtectHome = false;
      #         ReadWritePaths = [ "/home/${username}" ];
      #       };

      #       environment = {
      #         HOME = "/home/${username}";
      #         USER = username;
      #       };
      #     };
      #   }
      # ))
    ]
  );
}
