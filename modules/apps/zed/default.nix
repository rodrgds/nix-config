{
  lib,
  config,
  pkgs,
  username,
  system,
  constants,
  ...
}:
let
  cfg = config.apps.zed;
  inherit (constants) isDarwin isLinux;
in
{
  options.apps.zed = {
    enable = lib.mkEnableOption "Enable Zed";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      # Linux: Install via nixpkgs
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.unstable.zed-editor ];
      })
      # Darwin: Install via Homebrew cask
      (lib.optionalAttrs isDarwin {
        homebrew.casks = [ "zed" ];
      })
      {
        home-manager.users.${username} = {
          xdg.configFile."zed/settings.json".text = builtins.toJSON {
            theme = "One Dark";
            features.inline_completion = false;
            telemetry.metrics = false;
            telemetry.diagnostics = false;
          };
        };
      }
    ]
  );
}
