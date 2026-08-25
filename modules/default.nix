# Main modules entry point shared by NixOS and nix-darwin.
{
  constants,
  lib,
  ...
}:
{
  imports = [
    ./apps
    ./core
    ./profiles
    ./scripts
    ../secrets
  ]
  ++ lib.optionals constants.isLinux [
    ./hosting
    ./services
  ]
  ++ lib.optionals constants.isDarwin [
    ./darwin
  ];
}
