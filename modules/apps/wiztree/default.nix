# WizTree has no Linux build; rgo-desktop uses qdirstat instead.
{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
{
  options.apps.wiztree.enable = lib.mkEnableOption "WizTree disk space analyzer (macOS)";

  config = lib.mkIf config.apps.wiztree.enable (
    lib.optionalAttrs constants.isDarwin {
      home-manager.users.${username}.home.packages = [ pkgs.wiztree ];
    }
  );
}
