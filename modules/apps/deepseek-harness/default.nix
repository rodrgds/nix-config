{
  config,
  constants,
  lib,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.deepseek-harness;
  toolchain = config.apps.javascript-toolchain;
  nineRouterCatalog = import ../../shared/9router.nix;
  launcherDir = "${constants.homeDir}/.local/libexec/dsh/bin";
  launcherPath = "${launcherDir}/dsh";
  packageRoot = "${toolchain.npm.installRoot}/lib/node_modules/@deepseek-ai/dsh";
  pathShim = pkgs.writeShellScriptBin "dsh" ''
    exec ${lib.escapeShellArg launcherPath} "$@"
  '';

  # The upstream native probe assumes the official Node binary's layout and
  # fails on Nix builds. Use Node's exposed internals in every DSH worker too.
  # https://github.com/deepseek-ai/deepseek-harness/discussions/752
  nodeInternals = pkgs.writeText "dsh-nix-internals.cjs" ''
    const { createRequire } = require('node:module');
    const dshRequire = createRequire(${builtins.toJSON "${packageRoot}/package.json"});
    dshRequire('node-addon-require-builtin').requireBuiltin = require;
  '';

  patch = [
    {
      id = "llm-pi-ai";
      config.providers.nine-router = {
        displayName = "9Router (NAS)";
        apiKeyEnv = "NINE_ROUTER_API_KEY";
        api = "openai-completions";
        baseURL = cfg.nineRouter.baseURL;
        compat = {
          supportsStore = false;
          supportsDeveloperRole = false;
          maxTokensField = "max_tokens";
        };
        models = map (model: {
          id = model.alias;
          name = model.displayName;
        }) nineRouterCatalog.models;
      };
    }
    {
      id = "agent-default-model";
      config = {
        provider = "nine-router";
        model = cfg.nineRouter.defaultModel;
      };
    }
    {
      insert = [
        {
          id = "mcp-executor";
          name = "@deepseek-ai/dsh-mcp-client";
          config = {
            serverName = "executor";
            transport = "stdio";
            # DSH's HTTP client does not implement OAuth. mcp-remote owns
            # browser sign-in and refresh, using its normal credential store.
            command = "${toolchain.npm.binDir}/mcp-remote";
            args = [
              "https://executor.sh/rodrigo-dias/mcp"
              "--transport"
              "http-only"
              "--ignore-tool"
              "*-artifact*"
              "--ignore-tool"
              "read_executor_shell"
            ];
            toolCallTimeoutMs = 120000;
          };
        }
      ];
    }
  ];
in
{
  options.apps.deepseek-harness = {
    enable = lib.mkEnableOption "DeepSeek Harness with shared agent configuration";

    nineRouter = {
      baseURL = lib.mkOption {
        type = lib.types.str;
        default = "http://rgo-nas:20128/v1";
        description = "9Router OpenAI-compatible endpoint.";
      };
      defaultModel = lib.mkOption {
        type = lib.types.enum (map (model: model.alias) nineRouterCatalog.models);
        default = "flash";
        description = "9Router combo selected for new DeepSeek Harness sessions.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    apps.agents.enable = true;
    apps.javascript-toolchain = {
      enable = true;
      npm.cliPackages = {
        dsh.package = "@deepseek-ai/dsh@latest";
        mcp-remote.package = "mcp-remote@latest";
      };
    };

    home-manager.users.${username} =
      { config, lib, ... }:
      {
        sops.secrets.nine_router_api_key = { };
        home.packages = [ pathShim ];
        # Keep the secret-loading launcher ahead of the shared npm binary.
        home.sessionPath = lib.mkBefore [ launcherDir ];
        home.file = {
          # JSON is valid YAML. The home patch covers all base-backed profiles;
          # sessions and each profile's runtime settings remain writable.
          ".dsh/cordis.patch.yml".text = builtins.toJSON patch;
          ".local/libexec/dsh/bin/dsh" = {
            executable = true;
            text = ''
              #!${pkgs.bash}/bin/bash
              set -euo pipefail
              export NINE_ROUTER_API_KEY="$(${pkgs.coreutils}/bin/cat ${lib.escapeShellArg config.sops.secrets.nine_router_api_key.path})"
              exec ${toolchain.node.binPath} --expose-internals --require ${nodeInternals} \
                ${lib.escapeShellArg "${packageRoot}/lib/bin.js"} "$@"
            '';
          };
        };
      };
  };
}
