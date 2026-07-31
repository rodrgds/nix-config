# Apps modules - auto-discovered via import-tree
# Each subdirectory is a self-contained Nix module.
# Use /_ prefixed directories for helper files or modules you don't want auto-imported.
{ inputs, ... }:
{
  imports = [
    (inputs.import-tree.filter (p: p != "/default.nix") ./.)
  ];
}
