# Core modules entry point
# Cross-platform modules are auto-discovered via import-tree.
# Linux-only modules live under _linux/ (skipped on Darwin by /_ convention).
{
  inputs,
  lib,
  system,
  config,
  ...
}:
let
  isDarwin = lib.hasSuffix "-darwin" system;
  isLinux = !isDarwin;
in
{
  imports = [
    # Cross-platform modules (auto-discovered)
    # import-tree skips _linux/ by default because of /_ in path
    (inputs.import-tree.filter (p: p != "/default.nix") ./.)
  ]
  # Linux-only modules (NixOS-specific)
  # Relative paths inside _linux/ don't contain /_linux/ prefix,
  # so the default filter works correctly.
  ++ lib.optionals isLinux [
    (inputs.import-tree.filter (p: p != "/default.nix") ./_linux)
  ];
}
