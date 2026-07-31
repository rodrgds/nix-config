{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.antigravity;
  inherit (constants) isDarwin isLinux;
  installDir = ".local/bin";
  installUrl = "https://antigravity.google/cli/install.sh";
in
{
  options.apps.antigravity = {
    enable = lib.mkEnableOption "Enable Antigravity";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        # The Antigravity CLI ships as a single native Go binary via Google's
        # install script, not as an npm package. The script is idempotent (it
        # exits early when `agy` is already present) and the binary self-updates
        # in the background during regular runs, so we only run it on first
        # activation.
        home-manager.users.${username} =
          { lib, ... }:
          {
            home.activation.installAntigravityCli = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
              if [ ! -x "$HOME/${installDir}/agy" ]; then
                export PATH="${pkgs.curl}/bin:${pkgs.bash}/bin:${pkgs.coreutils}/bin:${pkgs.gnutar}/bin:${pkgs.gzip}/bin:${pkgs.gnused}/bin:$PATH"
                ${pkgs.curl}/bin/curl -fsSL ${installUrl} | ${pkgs.bash}/bin/bash
              fi
            '';
          };
      }
      (lib.optionalAttrs isDarwin {
        # On macOS the darwin_arm64 binary runs natively, so `~/.local/bin`
        # just needs to be on PATH.
        home-manager.users.${username} =
          { lib, ... }:
          {
            home.sessionPath = [ "$HOME/${installDir}" ];
          };
      })
      (lib.optionalAttrs isLinux {
        # The linux glibc build is dynamically linked against /lib64/ld-linux-
        # x86-64.so.2, which does not exist on NixOS. Wrap it in an FHS
        # environment (like the antigravity IDE's `-fhs` variant) so it can
        # find glibc. The raw binary is kept at `~/.local/bin/agy` (off PATH)
        # and the wrapper execs it from there.
        environment.systemPackages = [
          (pkgs.buildFHSEnv {
            name = "agy";
            runScript = "\"$HOME/${installDir}/agy\"";
          })
        ];
      })
    ]
  );
}
