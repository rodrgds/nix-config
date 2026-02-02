# Secrets management with sops-nix
{
  lib,
  config,
  pkgs,
  username,
  system,
  constants,
  ...
}:
let
  cfg = config.secrets;
  inherit (constants) homeDir;
in
{
  options.secrets = {
    enable = lib.mkEnableOption "Enable secrets management with sops-nix";
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${username} =
      { config, ... }:
      {
        sops = {
          age.keyFile = "${homeDir}/.config/sops/age/keys.txt";
          defaultSopsFile = ./secrets.yaml;

          secrets = {
            lastfm_api_key = { };
            lastfm_secret = { };
            lastfm_username = { };
            openai_api_key = { };
            user_email = { };
            location_latitude = { };
            location_longitude = { };
          };
        };
      };
  };
}
