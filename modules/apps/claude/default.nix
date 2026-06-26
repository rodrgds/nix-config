{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.claude;
  installDir = ".local/share/npm-global";
  packageName = "@anthropic-ai/claude-code";
in
{
  options.apps.claude = {
    enable = lib.mkEnableOption "Enable Claude";
  };

  config = lib.mkIf cfg.enable {
    apps.nodejs.enable = true;

    home-manager.users.${username} =
      { lib, ... }:
      {
        home.sessionPath = [ "$HOME/${installDir}/bin" ];

        home.activation.installClaudeCli = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          export PATH="${pkgs.nodejs}/bin:$PATH"
          INSTALL_ROOT="$HOME/${installDir}"

          mkdir -p "$INSTALL_ROOT"
          ${pkgs.nodejs}/bin/npm install --global --prefix "$INSTALL_ROOT" ${packageName}
        '';
      };
  };
}
