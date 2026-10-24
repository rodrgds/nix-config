{
  lib,
  config,
  constants,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.claude;
  managedConfig = pkgs.writeText "claude-code-config.json" (
    builtins.toJSON {
      mcpServers.executor = {
        type = "http";
        url = "https://executor.sh/rodrigo-dias/mcp";
      };
    }
  );
  configure = pkgs.writeShellApplication {
    name = "configure-claude-code";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.diffutils
      pkgs.jq
    ];
    text = builtins.readFile ./configure.sh;
  };
in
{
  options.apps.claude = {
    enable = lib.mkEnableOption "Enable Claude";
  };

  config = lib.mkIf cfg.enable {
    apps.agents.enable = true;
    apps.javascript-toolchain = {
      enable = true;
      npm.cliPackages.claude.package = "@anthropic-ai/claude-code@latest";
    };

    home-manager.users.${username} = { lib, ... }: {
      home.activation.configureClaudeCode =
        lib.hm.dag.entryAfter
          [
            "writeBoundary"
            "linkSkills"
          ]
          ''
            ${configure}/bin/configure-claude-code \
              "$HOME" \
              ${lib.escapeShellArg "${constants.homeDir}/.agents/skills"} \
              ${managedConfig}
          '';
    };
  };
}
