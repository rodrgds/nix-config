# Server services module
# Central module for all containerized services on the VPS
# Auto-discovered via import-tree — each subdirectory is a self-contained module.
{ inputs, lib, ... }:
{
  imports = [
    (inputs.import-tree.filter (p: p != "/default.nix") ./.)
  ];

  options.vps.enableAll = lib.mkEnableOption "Enable all VPS services";

  # Note: Individual services are enabled separately via vps.* namespace
}
