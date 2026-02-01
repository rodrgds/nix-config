{
  description = "NixOS and nix-darwin configuration with flakes and home-manager";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-24.11";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin = {
      url = "github:lnl7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-homebrew = {
      url = "github:zhaofengli/nix-homebrew";
      inputs.nixpkgs.follows = "nixpkgs";
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

    steam-config-nix = {
      url = "github:different-name/steam-config-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    vicinae = {
      url = "github:vicinaehq/vicinae";
    };

    vicinae-extensions = {
      url = "github:vicinaehq/extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nix-darwin,
      home-manager,
      nix-homebrew,
      sops-nix,
      steam-config-nix,
      vicinae,
      ...
    }@inputs:
    let
      # Common settings across all systems
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
            constants = mkConstants system;
          };
          modules = [
            # Apply overlays
            {
              nixpkgs.overlays = [ (import ./packages { inherit inputs; }) ];
            }
            # Main modules
            ./modules
            # Host-specific configuration
            ./hosts/${hostname}
            # Home-manager as NixOS module
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
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
                  vicinae.homeManagerModules.default
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
            constants = mkConstants system;
          };
          modules = [
            # Apply overlays
            {
              nixpkgs.overlays = [ (import ./packages { inherit inputs; }) ];
            }
            # App modules (with cross-platform support)
            ./modules/apps
            # Darwin-specific modules
            ./modules/darwin
            # Host-specific configuration
            ./hosts/${hostname}
            # Homebrew integration
            nix-homebrew.darwinModules.nix-homebrew
            # Home-manager as Darwin module
            home-manager.darwinModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
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

      # Darwin configurations
      darwinConfigurations.rgo-laptop = mkDarwinSystem {
        system = "aarch64-darwin";
        hostname = "rgo-laptop";
      };
    };
}
