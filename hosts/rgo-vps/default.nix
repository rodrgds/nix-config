# Host-specific configuration for rgo-vps (Hetzner Cloud)
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

  # Keep the VPS host's own DNS resolution independent of AdGuard Home.
  networking.nameservers = [
    "9.9.9.9"
    "149.112.112.112"
    "1.1.1.1"
    "1.0.0.1"
  ];

  # Add nix-openclaw overlay for openclaw package
  # nixpkgs.overlays = [ inputs.nix-openclaw.overlays.default ];

  # Enable a minimal, server-friendly subset of your modules.
  # Note: Don't use core.boot here - it enables systemd-boot (UEFI),
  # but Hetzner Cloud x86_64 uses BIOS/legacy boot.
  # core.boot.enable = true;
  core.nix.enable = true;
  core.users.enable = true;
  core.locale.enable = true;
  core.security.enable = true;
  core.system.enable = true;
  core.networking.enable = true;
  core.networking.tailscale.acceptDns = false;

  apps.nix-tools.enable = true;
  environment.systemPackages = [ pkgs.git ];

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

  # Services
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

  vps.trndb.enable = false;
  vps.termix.enable = false;
  vps.postiz.enable = false;
  vps.ghost.enable = false;
  vps.unieasy.enable = false;
  vps.pocketbase.enable = false;
  vps.immich-public-proxy.enable = false;
  vps.openpost.enable = true;

  # Your user module sets bash as the login shell.
  apps.bash.enable = true;

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
      constants.sshPublicKeys.rgo-desktop
      constants.sshPublicKeys.rgo-termix
    ];
  };

  security.sudo.wheelNeedsPassword = false;

  # OpenClaw AI assistant configuration
  # home-manager.users.${username} = {
  #   programs.openclaw = {
  #     enable = true;

  #     config = {
  #       gateway = {
  #         mode = "local";
  #         bind = "loopback";
  #         tailscale = {
  #           mode = "serve";
  #         };
  #         auth = {
  #           mode = "token";
  #           tokenFile = "/run/secrets/openclaw_gateway_token";
  #           allowTailscale = true;
  #         };
  #       };

  #       channels.telegram = {
  #         tokenFile = "/run/secrets/openclaw_telegram_token";
  #         allowFrom = [ constants.telegramChatId ];
  #       };

  #       agents = {
  #         defaults = {
  #           model = {
  #             primary = "zai/glm-4.7";
  #           };
  #           workspace = "/home/${username}/.openclaw/workspace";
  #         };
  #       };

  #       env = {
  #         vars = {
  #           ZAI_API_KEY = "/run/secrets/openclaw_zai_api_key";
  #         };
  #       };
  #     };

  #     # plugins = [
  #     #   { source = "github:openclaw/nix-steipete-tools?dir=tools/summarize"; }
  #     #   { source = "github:openclaw/nix-steipete-tools?dir=tools/peekaboo"; }
  #     #   { source = "github:openclaw/nix-steipete-tools?dir=tools/oracle"; }
  #     #   { source = "github:openclaw/nix-steipete-tools?dir=tools/sag"; }
  #     #   { source = "github:openclaw/nix-steipete-tools?dir=tools/camsnap"; }
  #     #   { source = "github:openclaw/nix-steipete-tools?dir=tools/gogcli"; }
  #     # ];

  #     instances.default = {
  #       enable = true;
  #       package = pkgs.openclaw;
  #       stateDir = "/home/${username}/.openclaw";
  #       workspaceDir = "/home/${username}/.openclaw/workspace";
  #       launchd.enable = false;
  #     };
  #   };
  # };

  # Tailscale Serve for OpenClaw
  # systemd.services.tailscale-serve-openclaw = {
  #   description = "Tailscale Serve for OpenClaw";
  #   after = [ "tailscaled.service" ];
  #   wants = [ "tailscaled.service" ];
  #   serviceConfig = {
  #     Type = "oneshot";
  #     RemainAfterExit = true;
  #     User = "root";
  #     ExecStart = "${pkgs.tailscale}/bin/tailscale serve --bg http://127.0.0.1:18789";
  #     ExecStop = "${pkgs.tailscale}/bin/tailscale serve off";
  #     StandardOutput = "journal";
  #     StandardError = "journal";
  #   };
  #   wantedBy = [ "multi-user.target" ];
  # };

  # Limit systemd journal to save RAM and disk (VPS has no need for extensive logs)
  services.journald.extraConfig = ''
    SystemMaxUse=50M
    SystemMaxFileSize=10M
    RuntimeMaxUse=10M
  '';

  # Disable wpa_supplicant WiFi (VPS is ethernet-only, saves ~15 MB RAM)
  networking.wireless.enable = lib.mkForce false;

  # Keep the classic D-Bus daemon on the remote VPS so live switch deployments
  # do not get blocked by the dbus -> broker migration inhibitor.
  services.dbus.implementation = "dbus";

  system.stateVersion = "24.11";
}
