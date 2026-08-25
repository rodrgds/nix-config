{
  lib,
  config,
  username,
  ...
}:
let
  cfg = config.apps.claude;
in
{
  options.apps.claude = {
    enable = lib.mkEnableOption "Enable Claude";
  };

  config = lib.mkIf cfg.enable {
    apps.javascript-toolchain = {
      enable = true;
      npm.cliPackages.claude.package = "@anthropic-ai/claude-code@latest";
    };
  };
}
