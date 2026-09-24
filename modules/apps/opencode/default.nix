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
  # Global agent skills. Single source of truth, shared with Pi via
  # ~/.agents/skills. Referenced by absolute path (not a Nix path) so the
  # config points at the mutable repo, not a /nix/store snapshot.
  skillsDir = "${constants.homeDir}/.config/home/modules/apps/agents/skills";
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
              autoupdate = true;
              model = "nine_router/good";
              # Native websearch (V2): Exa key comes from EXA_API_KEY,
              # exported from the sops secret in shell init below.
              websearch = {
                provider = "exa";
              };
              # Global agent skills, same set Pi uses.
              skills = [ skillsDir ];
              provider = {
                nine_router = {
                  npm = "@ai-sdk/openai-compatible";
                  name = "My 9Router (NAS)";
                  options = {
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
                  npm = "@ai-sdk/openai-compatible";
                  name = "Opencode Zen";
                  options = {
                    baseURL = "https://opencode.ai/zen/v1";
                    apiKey = "{env:OPENCODE_GO_API_KEY}";
                  };
                  models = {
                    "x-preview-f-free" = {
                      name = "Ox Alpha Free (0x)";
                    };
                    "muse-spark-1.2-contributor-free" = {
                      name = "Muse Spark 1.2 Free";
                    };
                    "muse-spark-1.3-contributor-free" = {
                      name = "Muse Spark 1.3 Free";
                    };
                  };
                };
                opencode-go = {
                  npm = "@ai-sdk/openai-compatible";
                  name = "Opencode Go";
                  options = {
                    baseURL = "https://opencode.ai/zen/go/v1";
                    apiKey = "{env:OPENCODE_GO_API_KEY}";
                  };
                  models = {
                    "muse-spark-1.2-contributor" = {
                      name = "Muse Spark 1.2 Contributor";
                    };
                    "muse-spark-1.3-contributor" = {
                      name = "Muse Spark 1.3 Contributor";
                    };
                  };
                };
              };
              # Native V2 shape. The V1 provider/model fields above are
              # still accepted and normalized in memory. MCP detail:
              # - hindsight points at the self-hosted per-bank MCP endpoint
              #   (bank `rodrigo`, same memory Pi uses), Bearer token from
              #   HINDSIGHT_API_TOKEN in shell init below.
              # - executor aggregates the remaining integrations (exa,
              #   context7, github, hindsight tools, vikunja, ...). Uses
              #   OAuth: run `opencode mcp auth executor` once per machine.
              mcp = {
                servers = {
                  hindsight = {
                    type = "remote";
                    url = "http://rgo-nas:8888/mcp/rodrigo/";
                    oauth = false;
                    headers = {
                      Authorization = "Bearer {env:HINDSIGHT_API_TOKEN}";
                    };
                  };
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

            programs.opencode = {
              enable = true;
              # Note: HM also installs nixpkgs opencode (still V1), but the
              # managed npm prefix comes first on PATH so `opencode` is V2.
              # package=null is not an option: the pinned HM module calls
              # versionAtLeast on null and fails evaluation.
              commands = {
                release = ''
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
            };

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
                "opencode/tui.json".text = builtins.toJSON {
                  theme = "flexoki";
                };
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
