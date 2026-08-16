{
  lib,
  config,
  pkgs,
  inputs,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.paseo;
  inherit (constants) isDarwin isLinux;
  paseoPkgs = inputs.paseo.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  options.apps.paseo = {
    enable = lib.mkEnableOption "Enable Paseo";

    desktop = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install the Paseo desktop app.";
    };

    cli = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install the Paseo CLI and daemon (`paseo`, `paseo-server`).";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        # The upstream flake tracks nixpkgs-unstable, which this repo does not
        # follow, so pull the packages from Paseo's own flake output instead of
        # the pinned nixpkgs. Its buildNpmPackage derivations already support
        # x86_64-linux and aarch64-linux.
        environment.systemPackages =
          lib.optionals cfg.cli [ paseoPkgs.default ] ++ lib.optionals cfg.desktop [ paseoPkgs.desktop ];
      })

      (lib.optionalAttrs isDarwin {
        # The notarized macOS desktop app ships as a Homebrew cask, which also
        # links the bundled `paseo` CLI. The upstream Nix desktop derivation
        # is a from-source Electron build and is intentionally not used here.
        homebrew.casks = lib.optionals cfg.desktop [ "paseo" ];
      })
    ]
  );
}
