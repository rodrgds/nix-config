# Core modules entry point
{ ... }:
{
  imports = [
    ./boot
    ./nix
    ./users
    ./locale
    ./environment
    ./security
    ./system
    ./audio
    ./fonts
    ./networking
    ./xserver
    ./nvidia
    ./peripherals
    ./printing
    ./docker
    ./downloads-cleanup
  ];
}
