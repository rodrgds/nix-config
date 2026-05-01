{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.codex;
  installDir = ".local/share/npm-global";
  packageName = "@openai/codex";
in
{
  options.apps.codex = {
    enable = lib.mkEnableOption "Enable Codex CLI";
  };

  config = lib.mkIf cfg.enable {
    apps.nodejs.enable = true;

    home-manager.users.${username} =
      { lib, ... }:
      {
        home.sessionPath = [ "$HOME/${installDir}/bin" ];

        home.activation.installCodexCli = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          export PATH="${pkgs.nodejs}/bin:$PATH"
          INSTALL_ROOT="$HOME/${installDir}"

          mkdir -p "$INSTALL_ROOT"
          ${pkgs.nodejs}/bin/npm install --global --prefix "$INSTALL_ROOT" ${packageName}
        '';
      };
  };
}
