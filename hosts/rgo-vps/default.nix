# Host-specific configuration for rgo-vps (Hetzner Cloud)
{
  constants,
  lib,
  username,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix
  ];

  networking.hostName = "rgo-vps";

  # Enable a minimal, server-friendly subset of your modules.
  # Note: Don't use core.boot here - it enables systemd-boot (UEFI),
  # but Hetzner Cloud x86_64 uses BIOS/legacy boot.
  # core.boot.enable = true;
  core.nix.enable = true;
  core.users.enable = true;
  core.locale.enable = true;
  core.environment.enable = true;
  core.security.enable = true;
  core.system.enable = true;
  core.networking.enable = true;

  # Headless defaults
  core.audio.enable = lib.mkForce false;
  core.xserver.enable = lib.mkForce false;
  core.fonts.enable = lib.mkForce false;
  core.peripherals.enable = lib.mkForce false;
  core.printing.enable = lib.mkForce false;

  # Enable VPS-specific secrets
  secrets.enable = true;
  secrets.isVps = true;

  # Enable server services infrastructure
  vps.enableAll = false;
  vps.caddy.enable = true;
  services.podman.enable = true;

  # Services ON
  vps.n8n.enable = true;
  vps.umami.enable = true;
  vps.vaultwarden.enable = true;
  vps.teamspeak.enable = true;
  vps.directus.enable = true;
  # Services OFF
  vps.ghost.enable = true;
  vps.unieasy.enable = false;
  vps.postiz.enable = false;
  vps.pocketbase.enable = false;
  vps.websites.enable = false;
  vps.deploy.enable = false;
  vps.immich-public-proxy.enable = false;

  # Your user module sets fish as the login shell.
  programs.fish.enable = true;

  # Bootloader for Hetzner Cloud (BIOS/legacy boot)
  # Note: Using mkForce to override any defaults
  boot.loader.grub = {
    enable = lib.mkForce true;
    devices = lib.mkForce [ "/dev/sda" ];
    efiSupport = lib.mkForce false;
  };

  services.openssh.enable = true;
  services.openssh.settings = {
    PermitRootLogin = "no";
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
  };

  networking.firewall.enable = lib.mkForce true;
  networking.firewall.allowedTCPPorts = [
    22 # SSH
    80 # HTTP
    443 # HTTPS
  ];

  # Ensure the user exists for SSH login.
  users.users.${username} = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      constants.sshPublicKeys.rgo-laptop
      constants.sshPublicKeys.rgopc
    ];
  };

  security.sudo.wheelNeedsPassword = false;

  # Limit systemd journal to save RAM and disk (VPS has no need for extensive logs)
  services.journald.extraConfig = ''
    SystemMaxUse=50M
    SystemMaxFileSize=10M
    RuntimeMaxUse=10M
  '';

  # Disable wpa_supplicant WiFi (VPS is ethernet-only, saves ~15 MB RAM)
  networking.wireless.enable = lib.mkForce false;

  system.stateVersion = lib.mkDefault "24.11";
}
