{
  constants,
  lib,
  inputs,
  username,
  pkgs,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix
  ];

  networking.hostName = "rgo-vps";

  networking.nameservers = [
    "9.9.9.9"
    "149.112.112.112"
    "1.1.1.1"
    "1.0.0.1"
  ];

  core.nix.enable = true;
  core.users.enable = true;
  core.locale.enable = true;
  core.security.enable = true;
  core.system.enable = true;
  core.networking.enable = true;
  core.networking.tailscale.acceptDns = false;

  apps.nix-tools.enable = true;
  environment.systemPackages = [ pkgs.git ];

  core.audio.enable = lib.mkForce false;
  core.xserver.enable = lib.mkForce false;
  core.fonts.enable = lib.mkForce false;
  core.peripherals.enable = lib.mkForce false;
  core.printing.enable = lib.mkForce false;

  secrets.enable = true;
  secrets.isVps = true;

  vps.enableAll = false;
  vps.caddy.enable = true;
  services.podman.enable = true;

  vps.adguardhome = {
    enable = true;
    dnsBindHosts = [
      "127.0.0.1"
      "100.69.139.47"
    ];
  };

  vps.umami.enable = true;
  vps.vaultwarden.enable = true;
  vps.teamspeak.enable = true;
  vps.directus.enable = true;
  vps.n8n.enable = true;
  vps.shlink = {
    enable = true;
    extraDomains = [ "ref.rgo.pt" ];
  };
  vps.websites = {
    enable = true;
    personal.enable = true;
    edu.enable = false;
  };
  vps.deploy.enable = true;
  vps.litellm = {
    enable = true;
    host = "0.0.0.0";
    port = 4000;
    zenApiBase = "https://opencode.ai/zen/v1";
    goApiBase = "https://opencode.ai/zen/go/v1";
    goAnthropicBase = "https://opencode.ai/zen/go";
    flashFreeModel = "openai/deepseek-v4-flash-free";
    flashPaidModel = "openai/deepseek-v4-flash";
    normalModel = "anthropic/minimax-m3";
    bestModel = "opencode-go/glm5.2";
    cooldownTime = 3600;
  };
  vps.openpost = {
    enable = true;
    edition = "cloud";
    image = "ghcr.io/rodrgds/openpost:v1.0.33";
  };
  vps.unprompted = {
    enable = true;
    domain = "unprompted.to";
    apiDomain = "api.unprompted.to";
  };

  vps.trndb.enable = false;
  vps.termix.enable = false;
  vps.postiz.enable = false;
  vps.ghost.enable = false;
  vps.unieasy.enable = false;
  vps.pocketbase.enable = false;
  vps.immich-public-proxy.enable = false;

  apps.bash.enable = true;

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
    22
    80
    443
  ];
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 4000 ];

  users.users.${username} = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      constants.sshPublicKeys.rgo-laptop
      constants.sshPublicKeys.rgo-desktop
      constants.sshPublicKeys.rgo-termix
    ];
  };

  security.sudo.wheelNeedsPassword = false;

  # Persistent swap file (VPS has only ~3.7 GiB RAM; builds OOM without this)
  swapDevices = [
    {
      device = "/swapfile";
      size = 2048;
      priority = -2;
    }
  ];

  services.journald.extraConfig = ''
    SystemMaxUse=50M
    SystemMaxFileSize=10M
    RuntimeMaxUse=10M
  '';

  networking.wireless.enable = lib.mkForce false;
  services.dbus.implementation = "dbus";

  system.stateVersion = "24.11";
}
