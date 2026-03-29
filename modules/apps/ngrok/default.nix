{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.ngrok;
  inherit (constants) homeDir;
in
{
  options.apps.ngrok = {
    enable = lib.mkEnableOption "Enable ngrok tunnel tool";
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${username} =
      { config, lib, ... }:
      {
        home.packages = [ pkgs.ngrok ];

        home.activation.setupNgrok = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          mkdir -p "${homeDir}/.config/ngrok"
          if [ -f "${config.sops.secrets.ngrok_auth_token.path}" ]; then
            cat > "${homeDir}/.config/ngrok/ngrok.yml" << EOF
          version: "2"
          authtoken: $(cat ${config.sops.secrets.ngrok_auth_token.path})
          EOF
            chmod 600 "${homeDir}/.config/ngrok/ngrok.yml"
          fi
        '';
      };
  };
}
