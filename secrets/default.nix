# Secrets management with sops-nix
{
  lib,
  config,
  pkgs,
  username,
  system,
  ...
}:
let
  cfg = config.secrets;
  isDarwin = lib.hasSuffix "-darwin" system;
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
          age.keyFile =
            if isDarwin then
              "/Users/${username}/.config/sops/age/keys.txt"
            else
              "/home/${username}/.config/sops/age/keys.txt";
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
