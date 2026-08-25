{
  lib,
  config,
  ...
}:
let
  cfg = config.darwin.apps.mCli;
in
{
  imports = [
    (lib.mkAliasOptionModule
      [
        "apps"
        "m-cli"
      ]
      [
        "darwin"
        "apps"
        "mCli"
      ]
    )
  ];

  options.darwin.apps.mCli = {
    enable = lib.mkEnableOption "Enable m-cli";
  };

  config = lib.mkIf cfg.enable {
    homebrew.brews = [ "m-cli" ];
  };
}
