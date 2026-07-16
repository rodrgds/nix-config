{
  description = "NixOS and nix-darwin configuration with flakes and home-manager";

  inputs = {
    # Default package set: keep the overall system on stable.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    # macOS must track a darwin-specific nixpkgs branch that matches nix-darwin.
    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-25.11-darwin";
    # Fast-moving packages can explicitly opt into unstable.
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    # DaVinci Resolve is intentionally pinned separately so normal flake updates
    # do not churn this heavyweight package unless you update this input.
    nixpkgs-davinci.url = "github:nixos/nixpkgs/755f5aa91337890c432639c60b6064bb7fe67769";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin = {
      url = "github:lnl7/nix-darwin/nix-darwin-25.11";
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

    steam-config-nix = {
      url = "github:different-name/steam-config-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    vicinae-extensions = {
      url = "github:vicinaehq/extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    devenv = {
      url = "github:cachix/devenv";
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

    # nix-openclaw = {
    #   url = "github:openclaw/nix-openclaw";
    # };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-darwin,
      nixpkgs-unstable,
      nixpkgs-davinci,
      nix-darwin,
      home-manager,
      nix-homebrew,
      sops-nix,
      disko,
      steam-config-nix,
      nix-index-database,
      angrr,
      # nix-openclaw,
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
                  # nix-openclaw.homeManagerModules.openclaw
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
            # Core modules (cross-platform)
            ./modules/core
            ./modules/scripts
            # App modules (with cross-platform support)
            ./modules/apps
            # Darwin-specific modules
            ./modules/darwin
            # Secrets management
            ./secrets
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

      # Darwin configurations
      darwinConfigurations.rgo-laptop = mkDarwinSystem {
        system = "aarch64-darwin";
        hostname = "rgo-laptop";
      };
    };
}
