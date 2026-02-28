{ pkgs }:
let
  sharedPackages = with pkgs; [
    inter
    jetbrains-mono
    iosevka
    nerd-fonts.jetbrains-mono
    nerd-fonts.iosevka
    source-serif
    bangers
    bricolage-grotesque
  ];

  linuxOnlyPackages = with pkgs; [
    font-awesome
    powerline-fonts
    corefonts
    vista-fonts
  ];
in
{
  inherit sharedPackages linuxOnlyPackages;
}
