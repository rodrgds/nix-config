{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.muse;
  installDir = ".local/bin";
  installUrl = "https://dev.meta.ai/install.sh";
  installScript = pkgs.writeShellScript "install-muse-code" ''
    set -eu
    export PATH="${pkgs.bash}/bin:${pkgs.coreutils}/bin:${pkgs.curl}/bin:$PATH"
    export MUSE_INSTALL_DIR="$HOME/${installDir}"
    export MUSE_NO_MODIFY_PATH=1
    ${pkgs.curl}/bin/curl -fsSL ${installUrl} | ${pkgs.bash}/bin/bash
  '';
in
{
  options.apps.muse = {
    enable = lib.mkEnableOption "Enable Muse Code";
  };

  config = lib.mkIf cfg.enable {
    # Muse's launcher downloads a checksum-verified native binary and updates it
    # in place. Its Linux build is statically linked, so it runs directly on
    # NixOS without an FHS wrapper.
    home-manager.users.${username} =
      { lib, ... }:
      {
        home.sessionPath = [ "$HOME/${installDir}" ];

        # The launcher handles its own hourly update checks during regular use;
        # activation only needs to bootstrap a machine that does not have it.
        home.activation.installMuseCode = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          if [ ! -x "$HOME/${installDir}/muse" ]; then
            ${installScript}
          fi
        '';
      };
  };
}
