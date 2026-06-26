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
  installDir = ".local/share/npm-global";
  installRoot = "${constants.homeDir}/${installDir}";
  packageName = "opencode-ai";
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
    litellm = {
      baseURL = lib.mkOption {
        type = lib.types.str;
        default = "http://rgo-vps:4000/v1";
        description = "LiteLLM OpenAI-compatible API base URL.";
      };

    };

    web = {
      enable = lib.mkEnableOption "Enable Opencode web";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        apps.nodejs.enable = true;

        home-manager.users.${username} =
          { config, lib, ... }:
          let
            litellmMasterKeyPath = config.sops.secrets.litellm_master_key.path;

            opencodeConfig = {
              "$schema" = "https://opencode.ai/config.json";
              autoupdate = true;
              theme = "flexoki-dark";
              model = "litellm/flash";
              plugin = [ "@mohak34/opencode-notifier@latest" ];
              provider = {
                litellm = {
                  npm = "@ai-sdk/openai-compatible";
                  name = "My LiteLLM (VPS)";
                  options = {
                    baseURL = cfg.litellm.baseURL;
                    apiKey = "{env:LITELLM_MASTER_KEY}";
                  };
                  models = {
                    flash = {
                      name = "Reeeeeally cheap model";
                    };
                    normal = {
                      name = "Pretty good model";
                    };
                    best = {
                      name = "Best OSS model";
                    };
                  };
                };
              };
              mcp = {
                svelte = {
                  type = "local";
                  command = [
                    "npx"
                    "-y"
                    "@sveltejs/mcp"
                  ];
                };
              }
              // lib.optionalAttrs isLinux {
                context7 = {
                  type = "remote";
                  url = "https://mcp.context7.com/mcp";
                  headers = {
                    CONTEXT7_API_KEY = config.sops.placeholder.context7_api_key;
                  };
                };
                exa = {
                  type = "remote";
                  url = "https://mcp.exa.ai/mcp";
                  headers = {
                    EXA_API_KEY = config.sops.placeholder.exa_api_key;
                  };
                };
              };
            };
          in
          (
            {
              home.sessionPath = [ "$HOME/${installDir}/bin" ];

              programs.opencode = {
                enable = true;
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

              home.activation.installOpencodeCli = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
                export PATH="${pkgs.nodejs}/bin:$PATH"
                INSTALL_ROOT="$HOME/${installDir}"

                mkdir -p "$INSTALL_ROOT"
                ${pkgs.nodejs}/bin/npm install --global --force --prefix "$INSTALL_ROOT" ${packageName}
              '';

              programs.bash.initExtra = lib.mkAfter ''
                if [ -z "''${LITELLM_MASTER_KEY:-}" ] && [ -r "${litellmMasterKeyPath}" ]; then
                  export LITELLM_MASTER_KEY="$(tr -d '\n' < "${litellmMasterKeyPath}")"
                fi
              '';

              programs.zsh.envExtra = lib.mkAfter ''
                if [ -z "''${LITELLM_MASTER_KEY:-}" ] && [ -r "${litellmMasterKeyPath}" ]; then
                  export LITELLM_MASTER_KEY="$(tr -d '\n' < "${litellmMasterKeyPath}")"
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
                  "opencode/opencode-notifier.json".text = builtins.toJSON {
                    sound = true;
                    notification = true;
                    timeout = 5;
                    showProjectName = true;
                    showSessionTitle = false;
                    showIcon = true;
                    suppressWhenFocused = true;
                    enableOnDesktop = false;

                    linux = {
                      grouping = false;
                    };
                    events = {
                      permission = {
                        sound = true;
                        notification = true;
                        command = true;
                      };
                      complete = {
                        sound = true;
                        notification = true;
                        command = true;
                      };
                      subagent_complete = {
                        sound = false;
                        notification = false;
                        command = true;
                      };
                      error = {
                        sound = true;
                        notification = true;
                        command = true;
                      };
                      question = {
                        sound = true;
                        notification = true;
                        command = true;
                      };
                      user_cancelled = {
                        sound = false;
                        notification = false;
                        command = true;
                      };
                      plan_exit = {
                        sound = true;
                        notification = true;
                        command = true;
                      };
                    };
                    messages = {
                      permission = "Session needs permission: {sessionTitle}";
                      complete = "Session has finished: {sessionTitle}";
                      subagent_complete = "Subagent task completed: {sessionTitle}";
                      error = "Session encountered an error: {sessionTitle}";
                      question = "Session has a question: {sessionTitle}";
                      user_cancelled = "Session was cancelled by user: {sessionTitle}";
                      plan_exit = "Plan ready for review: {sessionTitle}";
                    };
                    sounds = {
                      permission = null;
                      complete = null;
                      subagent_complete = null;
                      error = null;
                      question = null;
                      user_cancelled = null;
                      plan_exit = null;
                    };
                    volumes = {
                      permission = 1;
                      complete = 1;
                      subagent_complete = 1;
                      error = 1;
                      question = 1;
                      user_cancelled = 1;
                      plan_exit = 1;
                    };
                  };
                };

              home.sessionVariables = {
                OPENCODE_ENABLE_EXA = "1";
              };
            }
            // lib.optionalAttrs isLinux {
              sops.templates."opencode-config" = {
                content = builtins.toJSON opencodeConfig;
              };
            }
          );
      }
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.unstable.opencode-desktop ];
      })
      (lib.optionalAttrs isDarwin {
        homebrew.casks = [ "opencode-desktop" ];
      })
      (lib.optionalAttrs isLinux (
        lib.mkIf cfg.web.enable {
          systemd.services.opencode-web = {
            description = "Opencode Web Server";
            after = [
              "network.target"
              "tailscaled.service"
            ];
            wants = [ "tailscaled.service" ];
            wantedBy = [ "multi-user.target" ];

            serviceConfig = {
              Type = "simple";
              User = username;
              Group = "users";
              WorkingDirectory = "/home/${username}";
              ExecStart = "${installRoot}/bin/opencode web --hostname 0.0.0.0 --port 4096";
              Restart = "always";
              RestartSec = 5;
              NoNewPrivileges = true;
              PrivateTmp = true;
              ProtectSystem = "strict";
              ProtectHome = false;
              ReadWritePaths = [ "/home/${username}" ];
            };

            environment = {
              HOME = "/home/${username}";
              USER = username;
            };
          };
        }
      ))
    ]
  );
}
