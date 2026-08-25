# Secrets management with sops-nix
{
  lib,
  config,
  username,
  constants,
  ...
}:
let
  cfg = config.secrets;
  inherit (constants) homeDir isLinux isDarwin;

  vpsSecretsFile = ./vps-secrets.yaml;
  mainSecretsFile = ./secrets.yaml;
in
{
  options.secrets = {
    enable = lib.mkEnableOption "Enable secrets management with sops-nix";
    isVps = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Use VPS-specific secrets file";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      # System-level sops configuration (for VPS services)
      # Only available on NixOS/Linux - darwin doesn't have system-level sops
      (lib.optionalAttrs isLinux (
        lib.mkIf cfg.isVps {
          sops = {
            age.keyFile = "/root/.config/sops/age/keys.txt";
            defaultSopsFile = vpsSecretsFile;
          };
        }
      ))

      # Home-manager sops configuration for personal machines.
      # VPS doesn't need HM sops - system-level sops handles all VPS secrets,
      # and the user-level service can't read /root/.config/sops/age/keys.txt.
      (lib.mkIf (!cfg.isVps) {
        home-manager.users.${username} =
          { config, ... }:
          {
            sops = {
              age.keyFile = "${homeDir}/.config/sops/age/keys.txt";
              defaultSopsFile = mainSecretsFile;
            };
          };
      })
    ]
  );
}
