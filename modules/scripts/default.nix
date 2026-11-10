# Helper scripts and shared shell aliases.
#
# Scripts install as executables in ~/scripts (on PATH), each with an alias
# without its extension (`system_info`, `copy`, `screenshot`, ...). Desktop
# consumers (Hyprland, Quickshell, SketchyBar) run them from the checkout via
# `constants.scriptDir`. Most drive Linux/Wayland tools, so macOS only gets
# the cross-platform ones.
{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.scripts;
  inherit (constants) isDarwin isLinux homeDir;

  allScripts = builtins.attrNames (
    lib.filterAttrs (name: type: type == "regular" && name != "default.nix") (builtins.readDir ./.)
  );
  scriptNames = if isDarwin then [ "toggle_caffeine.sh" ] else allScripts;

  scriptAlias =
    name:
    let
      interpreter = if lib.hasSuffix ".sh" name then "bash " else "";
    in
    lib.nameValuePair (lib.removeSuffix ".py" (lib.removeSuffix ".sh" name)) "${interpreter}${homeDir}/scripts/${name}";

  aliases = {
    h = "cd ${homeDir}/.config/home";
    v = "nvim";
    glog = "git log --oneline --graph --decorate --all";
    ll = "ls -la";
    rebuild = "bun ${homeDir}/.config/home/tools/rebuild-wizard/rebuild.ts";
    copy = "pbcopy";
  }
  // lib.listToAttrs (map scriptAlias scriptNames)
  // lib.optionalAttrs isLinux {
    rescrobbled-logs = "journalctl --user -u rescrobbled.service -f";
  };
in
{
  options.scripts = {
    enable = lib.mkEnableOption "helper scripts and shell aliases";
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${username} = {
      home.file = lib.listToAttrs (
        map (
          name:
          lib.nameValuePair "scripts/${name}" {
            source = ./. + "/${name}";
            executable = true;
          }
        ) scriptNames
      );
      home.sessionPath = [ "${homeDir}/scripts" ];
      home.shellAliases = aliases;

      # The rebuild wizard deploys the VPS with this binary-cached client.
      home.packages = lib.optionals (!(config.secrets.isVps or false)) [ pkgs.deploy-rs ];

      sops.secrets = {
        openrouter_api_key = { };
      }
      // lib.optionalAttrs isLinux {
        # twitter_reply.py reads this key.
        openai_api_key = { };
      };
    };
  };
}
