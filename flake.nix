{
  description = "NixOS configuration with flakes and home-manager";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-24.11";

    home-manager = {
      url = "github:nix-community/home-manager";
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
      home-manager,
      sops-nix,
      steam-config-nix,
      vicinae,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      username = "rgo";
      fullname = "Rodrigo Dias";
      constants = import ./modules/constants.nix;
    in
    {
      nixosConfigurations.rgopc = nixpkgs.lib.nixosSystem {
        inherit system;

        specialArgs = {
          inherit
            inputs
            username
            fullname
            constants
            ;
        };

        modules = [
          # Apply overlays
          {
            nixpkgs.overlays = [ (import ./packages { inherit inputs; }) ];
          }

          # Main modules
          ./modules

          # Host-specific configuration
          ./hosts/rgopc

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
                  constants
                  ;
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
    };
}
