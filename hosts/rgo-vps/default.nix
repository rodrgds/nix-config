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
  apps.typst.enable = true;
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
  vps.hosting.sites = {
    personal.enable = true;
    edu.enable = true;
  };
  vps.hosting.deployments.enable = true;
  vps.litellm = {
    enable = true;
    host = "0.0.0.0";
    port = 4000;
    cooldownTime = 3600;
  };
  vps.openpost = {
    enable = true;
    edition = "cloud";
    # The signed deployment hook pulls and verifies an immutable digest, then
    # updates the local latest tag. Never let a service restart pull a mutable
    # tag behind the deployment gate.
    pullPolicy = "never";
    extraEnvironment = {
      OPENPOST_FEEDBACK_ENABLED = "true";
      OPENPOST_FEEDBACK_RECIPIENT = "OpenPost team";
      OPENPOST_VIDEO_STUDIO_ENABLED = "true";
    };
  };
  vps.montra.enable = true;
  vps.unprompted = {
    enable = true;
    domain = "unprompted.to";
    apiDomain = "api.unprompted.to";
    # First four-image release verified and promoted by CI run 31143879834.
    bootstrapRevision = "1eff53753993ebafdfaf57f66c841a0f89bb4fcf";
    bootstrapDigests = {
      api = "sha256:a100448e53ed9217641248a824b826e3ac3d40d4aabfe905068cf9657cd95d1d";
      worker = "sha256:8b86621abc25ad5a044fc9ea2511e9434714096ea55d183a5d950ab7850191d9";
      web = "sha256:1f6d46e995b60b3926efde6f07e766181b77c8938a01547196cbf8ca13e9d0ff";
      migrate = "sha256:48b42d5615381781eb5643e6094e481e1ca13d696ed400fdc22686dfd1d92fce";
    };
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
      constants.sshPublicKeys.hermes-nas
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
