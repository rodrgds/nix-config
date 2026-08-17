{
  constants,
  lib,
  inputs,
  username,
  pkgs,
  ...
}:
let
  rootDisk = import ./root-disk.nix;
in
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

  # Deploys flow through the webhook and deploy-rs (rebuild --vps); the
  # generic root-run auto-upgrade poll of main would race that pipeline and
  # re-apply config out of band. Keep the core default disabled here.
  system.autoUpgrade.enable = lib.mkForce false;

  # Keep GC out of the 00:00/04:00 maintenance windows.
  nix.gc.dates = lib.mkForce "*-*-* 05:30:00";

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

  # OpenPost uses PostHog, but Montra still depends on the shared Umami service.
  vps.umami.enable = true;
  vps.vaultwarden.enable = true;
  vps.teamspeak.enable = true;
  vps.directus.enable = true;
  vps.shlink = {
    enable = true;
    extraDomains = [ "ref.rgo.pt" ];
  };
  apps.typst.enable = true;
  vps.hosting.sites = {
    personal.enable = true;
  };
  vps.hosting.deployments.enable = true;
  vps."9router" = {
    enable = true;
    bindAddress = "100.69.139.47";
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
      OPENPOST_MEME_GENERATOR_ENABLED = "true";
      # Keep the legacy flag until the always-on Video Editor release reaches production.
      OPENPOST_VIDEO_STUDIO_ENABLED = "true";
    };
  };
  vps.montra = {
    enable = true;
    # Seed an empty local image store from the exact images currently verified
    # in production. Later webhook deploys promote only scanned immutable
    # digests and retain these values solely as disaster-recovery bootstrap.
    bootstrapImages = {
      api = {
        digest = "sha256:70733c9e4fbc8abacd544a08a10790ab525db4b381c7cc4c816b08bd739b034e";
        revision = "ad3e6c2b0689466b645ac0fbe22d3d2c3a209cc8";
      };
      web = {
        digest = "sha256:467b86c830b437fbf37684b13b0857ef061f29adefbb596b0f9980ca9e172602";
        revision = "ad3e6c2b0689466b645ac0fbe22d3d2c3a209cc8";
      };
      embedding = {
        digest = "sha256:270e36f83ebb568df9897374e8562b2401aad801a7056f8e78a8dc6f552762e1";
        revision = "8bdd89d5da25228e9dd246dd75d12203edcdfabe";
      };
      detector = {
        digest = "sha256:7cb8849af875af47086d57900494697b73e3e495ab39ff1b3f1bbce0526f4086";
        revision = "25e28eb6eeb9b41ce98e8ed7abc03b89c2b0fe64";
      };
      postgres = {
        digest = "sha256:084ef441551b6cc1c90657d4d1cb06468205971907adb204751191221c71ad7a";
        revision = "27e5541bdd078df48249fdec7781bc4e3fc4e331";
      };
    };
  };
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

  vps.n8n.enable = false;
  vps.trndb.enable = false;
  vps.termix.enable = false;
  vps.postiz.enable = false;
  vps.ghost.enable = false;
  vps.unieasy.enable = false;
  vps.pocketbase.enable = false;
  vps.immich-public-proxy.enable = false;

  vps.glances = {
    enable = true;
    bindAddress = "100.69.139.47";
  };

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
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ ];

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

  # Mount root by filesystem UUID instead of the GPT partition label. The Aug
  # 2026 boot failure was caused by partition 3's GPT name (disk-main-root)
  # vanishing while the ext4 filesystem itself stayed intact; the initrd waits
  # for /dev/disk/by-partlabel/disk-main-root and would not boot. A UUID-based
  # mount survives that class of GPT metadata loss. The same UUID is pinned in
  # disko.nix so a disaster-recovery reinstall reproduces it (see root-disk.nix).
  fileSystems."/".device = lib.mkForce "/dev/disk/by-uuid/${rootDisk.uuid}";

  # Root slice memory protection: let systemd-oomd reclaim under pressure
  # instead of the whole VM hanging and being power-cycled.
  systemd.oomd = {
    enable = true;
    enableRootSlice = true;
  };

  services.journald.extraConfig = ''
    SystemMaxUse=512M
    SystemMaxFileSize=64M
    RuntimeMaxUse=64M
  '';

  networking.wireless.enable = lib.mkForce false;
  services.dbus.implementation = "dbus";

  system.stateVersion = "24.11";
}
