# Hosted applications and their deployment control plane.
{ inputs, ... }:
{
  imports = [
    (inputs.import-tree.filter (p: p != "/default.nix") ./.)
  ];
}
