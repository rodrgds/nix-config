{
  description = "NixOS and nix-darwin configuration with flakes and home-manager";

  inputs = {
    # Default package set: keep the overall system on stable.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    # macOS must track a darwin-specific nixpkgs branch that matches nix-darwin.
    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";
    # Fast-moving packages can explicitly opt into unstable.
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Hermes Desktop is built from the upstream flake on Linux. macOS uses
    # the signed Homebrew cask, while sharing the same declarative remote
    # connection and SOPS token module.
    hermes-agent.url = "github:NousResearch/hermes-agent";

    nix-darwin = {
      url = "github:lnl7/nix-darwin/nix-darwin-26.05";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };

    nix-homebrew = {
      url = "github:zhaofengli/nix-homebrew";
    };

    nix-flatpak = {
      url = "github:gmodena/nix-flatpak/?ref=v0.7.0";
    };

    android-nixpkgs = {
      url = "github:tadfisher/android-nixpkgs/stable";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    affinity-nix = {
      url = "github:mrshmllow/affinity-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    steam-config-nix = {
      url = "github:different-name/steam-config-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    vicinae-extensions = {
      url = "github:vicinaehq/extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Source for the lightweight macOS border helper. Pin it because the
    # helper uses private frameworks whose contract can change with macOS.
    omacosy = {
      url = "github:paulsp94/omacosy/9e60b396b5e48a862bcb46bca5f2b13a63a822aa";
      flake = false;
    };

    # Use Vicinae's own package set so its package and NixOS module stay aligned.
    vicinae.url = "github:vicinaehq/vicinae";

    devenv = {
      # 32f6747 builds a binary that segfaults while generating completions on
      # x86_64-linux. Keep the last known-good revision until upstream moves on.
      url = "github:cachix/devenv/e30eb49258bee68353bd9c619823f635f4afa86c";
    };

    handy = {
      url = "github:cjpais/Handy";
      #inputs.nixpkgs.follows = "nixpkgs";
    };

    import-tree = {
      url = "github:vic/import-tree";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    angrr = {
      url = "github:linyinfeng/angrr";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-darwin,
      nixpkgs-unstable,
      nix-darwin,
      home-manager,
      nix-homebrew,
      sops-nix,
      disko,
      deploy-rs,
      steam-config-nix,
      nix-index-database,
      angrr,
      ...
    }@inputs:
    let
      # Common settings across all systems
      linuxLib = nixpkgs.lib;
      username = "rgo";
      fullname = "Rodrigo Dias";
      mkConstants = system: import ./modules/constants.nix { inherit username system; };

      # Helper function to create NixOS configurations
      mkNixosSystem =
        { system, hostname }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit
              inputs
              username
              fullname
              system
              ;
            lib = linuxLib;
            constants = mkConstants system;
            devenvPkg = inputs.devenv.packages.${system}.default;
          };
          modules = [
            # Apply overlays
            {
              nixpkgs.overlays = [
                inputs.angrr.overlays.default
                (import ./packages { inherit inputs; })
              ];
            }
            # Main modules
            ./modules
            # Host-specific configuration
            ./hosts/${hostname}
            # Disk partitioning/module (only when a host imports disko config)
            disko.nixosModules.disko
            # sops-nix for system-level secrets
            sops-nix.nixosModules.sops
            # nix-index-database for comma and command-not-found
            nix-index-database.nixosModules.nix-index
            # angrr for automatic GC root retention
            angrr.nixosModules.angrr
            # Register the options everywhere; hosts still opt in separately.
            inputs.vicinae.nixosModules.default
            # Declarative Flatpak manager
            inputs.nix-flatpak.nixosModules.nix-flatpak
            # Home-manager as NixOS module
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                backupFileExtension = "hm-bak";
                extraSpecialArgs = {
                  inherit
                    inputs
                    username
                    fullname
                    system
                    ;
                  constants = mkConstants system;
                };
                sharedModules = [
                  sops-nix.homeManagerModules.sops
                  steam-config-nix.homeModules.default
                  inputs.vicinae.homeManagerModules.default
                ];
              };
            }
          ];
        };

      # Helper function to create Darwin configurations
      mkDarwinSystem =
        { system, hostname }:
        nix-darwin.lib.darwinSystem {
          inherit system;
          specialArgs = {
            inherit
              inputs
              username
              fullname
              system
              ;
            inherit (nixpkgs-darwin) lib;
            constants = mkConstants system;
            devenvPkg = inputs.devenv.packages.${system}.default;
          };
          modules = [
            # Apply overlays
            {
              nixpkgs.overlays = [
                inputs.angrr.overlays.default
                (import ./packages { inherit inputs; })
              ];
            }
            # Shared module root
            ./modules
            # Host-specific configuration
            ./hosts/${hostname}
            # nix-index-database for comma and command-not-found
            nix-index-database.darwinModules.nix-index
            # angrr for automatic GC root retention
            angrr.darwinModules.angrr
            # Homebrew integration
            nix-homebrew.darwinModules.nix-homebrew
            # Home-manager as Darwin module
            home-manager.darwinModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                backupFileExtension = "hm-bak";
                extraSpecialArgs = {
                  inherit
                    inputs
                    username
                    fullname
                    system
                    ;
                  constants = mkConstants system;
                };
                sharedModules = [
                  sops-nix.homeManagerModules.sops
                ];
              };
            }
          ];
        };
    in
    {
      # NixOS configurations
      nixosConfigurations.rgo-desktop = mkNixosSystem {
        system = "x86_64-linux";
        hostname = "rgo-desktop";
      };

      nixosConfigurations.rgo-vps = mkNixosSystem {
        system = "x86_64-linux";
        hostname = "rgo-vps";
      };

      deploy.nodes.rgo-vps = {
        hostname = "rgo-vps";
        sshUser = "rgo";
        user = "root";
        remoteBuild = false;
        autoRollback = true;
        magicRollback = true;
        activationTimeout = 1800;
        confirmTimeout = 60;
        profiles.system.path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.rgo-vps;
      };

      apps = {
        aarch64-darwin.deploy-rs = deploy-rs.apps.aarch64-darwin.deploy-rs // {
          meta.description = "Deploy the rgo-vps NixOS configuration";
        };
        x86_64-linux.deploy-rs = deploy-rs.apps.x86_64-linux.deploy-rs // {
          meta.description = "Deploy the rgo-vps NixOS configuration";
        };
      };

      checks.x86_64-linux = deploy-rs.lib.x86_64-linux.deployChecks self.deploy // {
        vps-security-policy =
          let
            vps = self.nixosConfigurations.rgo-vps.config;
          in
          assert linuxLib.assertMsg (
            vps.services.getty.autologinUser == null
          ) "The VPS must require authentication on virtual and serial consoles";
          assert linuxLib.assertMsg (
            vps.networking.firewall.enable
            && vps.services.openssh.settings.PermitRootLogin == "no"
            && !vps.services.openssh.settings.PasswordAuthentication
            && !vps.services.openssh.settings.KbdInteractiveAuthentication
          ) "The VPS must retain its firewall and key-only, non-root SSH access";
          assert linuxLib.assertMsg (
            !vps.vps.adguardhome.enable
            || (
              vps.services.adguardhome.host == "127.0.0.1"
              && vps.services.adguardhome.settings.http.address == "127.0.0.1:3001"
            )
          ) "Unauthenticated AdGuard administration must stay on loopback";
          assert linuxLib.assertMsg (
            !vps.vps.shlink.enable
            || vps.virtualisation.oci-containers.containers.shlink.podman.sdnotify == "healthy"
          ) "Shlink startup must wait for application health before deployment acceptance";
          assert linuxLib.assertMsg (
            !vps.vps.unprompted.enable
            || vps.virtualisation.oci-containers.containers.unprompted-postgres.podman.sdnotify == "healthy"
          ) "Unprompted PostgreSQL must be ready before deployment acceptance";
          nixpkgs.legacyPackages.x86_64-linux.runCommand "check-vps-security-policy" { } ''
            touch "$out"
          '';
        umami-proxy-boundary =
          let
            pkgs = nixpkgs.legacyPackages.x86_64-linux;
            route = pkgs.writeText "umami-route.json" (
              builtins.toJSON {
                caddy =
                  self.nixosConfigurations.rgo-vps.config.services.caddy.virtualHosts."cool.rgo.pt".extraConfig;
                directus =
                  self.nixosConfigurations.rgo-vps.config.services.caddy.virtualHosts."directus.rgo.pt".extraConfig;
              }
            );
          in
          pkgs.runCommand "check-umami-proxy-boundary"
            {
              nativeBuildInputs = [
                self.nixosConfigurations.rgo-vps.config.services.caddy.package
                pkgs.python3
              ];
            }
            ''
              caddy version
              caddy adapt --adapter caddyfile \
                --config ${self.nixosConfigurations.rgo-vps.config.services.caddy.configFile} > /dev/null
              python3 ${./modules/services/caddy/tests/umami-boundary.py} ${route}
              touch "$out"
            '';
        shlink-private-redis =
          let
            pkgs = nixpkgs.legacyPackages.x86_64-linux;
            command = pkgs.writeText "shlink-redis-command.json" (
              builtins.toJSON self.nixosConfigurations.rgo-vps.config.virtualisation.oci-containers.containers.shlink-redis.cmd
            );
          in
          pkgs.runCommand "check-shlink-private-redis"
            {
              nativeBuildInputs = [
                pkgs.redis
                pkgs.python3
              ];
            }
            ''
              python3 ${./modules/services/shlink/tests/redis-boundary.py} ${command}
              touch "$out"
            '';
        nas-backup-contracts =
          let
            pkgs = nixpkgs.legacyPackages.x86_64-linux;
          in
          pkgs.runCommand "check-nas-backup-contracts"
            {
              nativeBuildInputs = with pkgs; [
                (python3.withPackages (ps: [ ps.boto3 ]))
                bash
                gzip
                gnutar
                sqlite
              ];
            }
            ''
              mkdir -p modules/shared tests
              cp -R ${./modules/shared/nas-backup} modules/shared/nas-backup
              cp ${./tests/test_nas_backup.py} tests/test_nas_backup.py
              cp ${./tests/test_nas_freshness.py} tests/test_nas_freshness.py
              cp ${./tests/test_nas_receiver_resources.py} tests/test_nas_receiver_resources.py
              export PYTHONDONTWRITEBYTECODE=1
              python3 -m unittest discover -s tests -p 'test_nas*.py' -v
              touch "$out"
            '';
        claude-configuration =
          nixpkgs.legacyPackages.x86_64-linux.runCommand "check-claude-configuration"
            {
              nativeBuildInputs = with nixpkgs.legacyPackages.x86_64-linux; [
                bash
                coreutils
                diffutils
                jq
                python3
              ];
            }
            ''
              python3 ${./modules/apps/claude}/test_configure.py
              touch "$out"
            '';
        montra-deploy-payloads =
          nixpkgs.legacyPackages.x86_64-linux.runCommand "check-montra-deploy-payloads"
            {
              nativeBuildInputs = [ nixpkgs.legacyPackages.x86_64-linux.jq ];
            }
            ''
              ${./modules/hosting/deployments/check-montra-payloads.sh}
              touch "$out"
            '';
        podman-health-unit-cleanup =
          nixpkgs.legacyPackages.x86_64-linux.runCommand "check-podman-health-unit-cleanup"
            {
              nativeBuildInputs = with nixpkgs.legacyPackages.x86_64-linux; [
                bash
                coreutils
                diffutils
              ];
            }
            ''
              bash ${./modules/services/podman/tests/health-unit-cleanup.sh} \
                ${./modules/services/podman/health-unit-cleanup.sh}
              touch "$out"
            '';
      };

      checks.aarch64-darwin.rgo-laptop =
        self.darwinConfigurations.rgo-laptop.config.system.build.toplevel;

      # Darwin configurations
      darwinConfigurations.rgo-laptop = mkDarwinSystem {
        system = "aarch64-darwin";
        hostname = "rgo-laptop";
      };
    };
}
