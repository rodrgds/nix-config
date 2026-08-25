{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.codex;
in
{
  options.apps.codex = {
    enable = lib.mkEnableOption "Enable Codex";
  };

  config = lib.mkIf cfg.enable {
    apps.javascript-toolchain = {
      enable = true;
      npm.cliPackages.codex.package = "@openai/codex@latest";
    };
    environment.systemPackages = lib.optionals pkgs.stdenv.isLinux [ pkgs.bubblewrap ];
  };
}
