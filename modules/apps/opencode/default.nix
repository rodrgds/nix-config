{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.opencode;
in
{
  options.apps.opencode = {
    enable = lib.mkEnableOption "Enable Opencode CLI";
  };

  config = lib.mkIf cfg.enable {
    # Install opencode CLI
    environment.systemPackages = [ pkgs.opencode ];

    home-manager.users.${username} =
      { config, ... }:
      {
        programs.opencode = {
          enable = true;
          skills = lib.mapAttrs (name: _: builtins.readFile (./skills + "/${name}")) (
            lib.attrsets.filterAttrs (_: type: type == "regular") (builtins.readDir ./skills)
          );
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

        sops.templates."opencode-config".content = builtins.toJSON {
          "$schema" = "https://opencode.ai/config.json";
          autoupdate = true;
          theme = "gruvbox";
          plugin = [ "@mohak34/opencode-notifier@latest" ];
          mcp = {
            svelte = {
              type = "local";
              command = [
                "npx"
                "-y"
                "@sveltejs/mcp"
              ];
            };
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

        xdg.configFile."opencode/opencode.json".source =
          config.lib.file.mkOutOfStoreSymlink
            config.sops.templates."opencode-config".path;

        xdg.configFile."opencode/opencode-notifier.json".text = builtins.toJSON {
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

        home.sessionVariables = {
          OPENCODE_ENABLE_EXA = "1";
        };
      };
  };
}
