{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.pi;
  installDir = ".local/share/npm-global";
  packageName = "@mariozechner/pi-coding-agent";
in
{
  options.apps.pi = {
    enable = lib.mkEnableOption "Enable Pi";
  };

  config = lib.mkIf cfg.enable {
    apps.nodejs.enable = true;

    # Essential CLI tools for pi
    environment.systemPackages = [
      pkgs.ripgrep
      pkgs.fd
    ];

    # Keep GUI tools able to resolve them
    home-manager.users.${username} =
      { lib, pkgs, ... }:
      {
        home.packages = [
          pkgs.ripgrep
          pkgs.fd
        ];

        home.sessionPath = [ "$HOME/${installDir}/bin" ];

        home.activation.installPiCli = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          export PATH="${pkgs.nodejs}/bin:$PATH"
          INSTALL_ROOT="$HOME/${installDir}"

          mkdir -p "$INSTALL_ROOT"
          ${pkgs.nodejs}/bin/npm install --global --prefix "$INSTALL_ROOT" ${packageName}
        '';

        home.file = {
          ".pi/agent/settings.json".text = builtins.toJSON {
            npmCommand = [ "${pkgs.nodejs}/bin/npm" ];
          };
        };
      };
  };
}
