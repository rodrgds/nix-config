{
  lib,
  config,
  ...
}:
let
  cfg = config.darwin.apps.cocoapods;
in
{
  imports = [
    (lib.mkAliasOptionModule
      [
        "apps"
        "cocoapods"
      ]
      [
        "darwin"
        "apps"
        "cocoapods"
      ]
    )
  ];

  options.darwin.apps.cocoapods = {
    enable = lib.mkEnableOption "Enable CocoaPods";
  };

  config = lib.mkIf cfg.enable {
    homebrew.brews = [ "cocoapods" ];
  };
}
