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
  inherit (constants) homeDir isDarwin;
  ngrokDir = if isDarwin then "${homeDir}/Library/Application Support/ngrok" else "${homeDir}/.config/ngrok";
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
          mkdir -p "${ngrokDir}"
          if [ -f "${config.sops.secrets.ngrok_auth_token.path}" ]; then
            cat > "${ngrokDir}/ngrok.yml" << EOF
          version: "2"
          authtoken: $(cat ${config.sops.secrets.ngrok_auth_token.path})
          EOF
            chmod 600 "${ngrokDir}/ngrok.yml"
          fi
        '';

        home.activation.setupNgrokSymlink = lib.mkIf isDarwin (
          lib.hm.dag.entryAfter [ "setupNgrok" ] ''
            mkdir -p "${homeDir}/.config/ngrok"
            ln -sf "${ngrokDir}/ngrok.yml" "${homeDir}/.config/ngrok/ngrok.yml"
          ''
        );
      };
  };
}
