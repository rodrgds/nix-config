# Core modules entry point
{
  lib,
  system,
  config,
  ...
}:
let
  isDarwin = lib.hasSuffix "-darwin" system;
  isLinux = !isDarwin;
in
{
  options.services.openclaw.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable OpenClaw AI assistant";
  };

  # config = lib.mkIf config.services.openclaw.enable {
  #   sops.secrets = {
  #     openclaw_telegram_token = { };
  #     openclaw_zai_api_key = { };
  #     openclaw_gateway_token = { };
  #   };
  # };

  imports = [
    # Cross-platform modules
    ./downloads-cleanup
    ./nix
  ]
  # Linux-only modules (NixOS-specific)
  ++ lib.optionals isLinux [
    ./users
    ./security
    ./system
    ./fonts
    ./networking
    ./boot
    ./audio
    ./locale
    ./xserver
    ./nvidia
    ./peripherals
    ./printing
    ./docker
  ];
}
