# Core modules entry point
{ lib, system, ... }:
let
  isDarwin = lib.hasSuffix "-darwin" system;
  isLinux = !isDarwin;
in
{
  imports = [
    # Cross-platform modules
    ./downloads-cleanup
  ]
  # Linux-only modules (NixOS-specific)
  ++ lib.optionals isLinux [
    ./nix
    ./users
    ./security
    ./system
    ./fonts
    ./networking
    ./boot
    ./audio
    ./environment
    ./locale
    ./xserver
    ./nvidia
    ./peripherals
    ./printing
    ./docker
  ];
}
