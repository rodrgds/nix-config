# Darwin core modules
# Auto-discovered via import-tree — each subdirectory is a self-contained module.
{ inputs, ... }:
{
  imports = [
    (inputs.import-tree.filter (p: p != "/default.nix") ./.)
  ];
}
