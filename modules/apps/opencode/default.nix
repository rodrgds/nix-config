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
  opencodeSkills =
    if builtins.pathExists ./skills then
      lib.mapAttrs' (
        name: _:
        lib.nameValuePair "opencode/skills/${lib.removeSuffix ".md" name}/SKILL.md" {
          source = ./skills + "/${name}";
        }
      ) (lib.attrsets.filterAttrs (_: type: type == "regular") (builtins.readDir ./skills))
    else
      { };
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
          npm.retiredPackages = [ "@vectorize-io/hindsight-coding-agents" ];
        };

        home-manager.users.${username} =
          { config, lib, ... }:
          let
            nineRouterApiKeyPath = config.sops.secrets.nine_router_api_key.path;
            opencodeGoApiKeyPath = config.sops.secrets.opencode_go_api_key.path;
            exaApiKeyPath = config.sops.secrets.exa_api_key.path;

            opencodeConfig = {
              "$schema" = "https://opencode.ai/config.json";
              update = "auto";
              # Native websearch (V2): Exa key comes from EXA_API_KEY,
              # exported from the sops secret in shell init below.
              websearch = {
                provider = "exa";
              };
              # Global agent skills shared with the other harnesses.
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
              # Executor aggregates the integrations (exa, context7, github).
              # Uses OAuth: run `opencode mcp auth executor` once per machine.
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
            sops = {
              secrets = {
                nine_router_api_key = { };
                exa_api_key = { };
                opencode_go_api_key = { };
              };
            }
            // lib.optionalAttrs isLinux {
              templates."opencode-config" = {
                content = builtins.toJSON opencodeConfig;
              };
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

            # Remove the retired coding-agent config left by older generations.
            home.activation.removeRetiredAgentMemoryConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
              retired_dir=${lib.escapeShellArg "${config.home.homeDirectory}/.hindsight"}
              ${pkgs.coreutils}/bin/rm -f "$retired_dir/coding-agent.json" "$retired_dir/coding-agent.json.tmp"
              ${pkgs.coreutils}/bin/rmdir "$retired_dir" 2>/dev/null || true
            '';
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
