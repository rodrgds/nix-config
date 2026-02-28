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
  cfg = config.apps.handy;
  inherit (constants) isLinux isDarwin;
in
{
  options.apps.handy = {
    enable = lib.mkEnableOption "Enable Handy - Speech-to-text application";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.handy ];
        environment.sessionVariables = {
          WEBKIT_DISABLE_DMABUF_RENDERER = "1";
        };
      })
      (lib.optionalAttrs isDarwin {
        homebrew.casks = [ "handy" ];

        home-manager.users.${username} = {
          homebrew.masApps = { };

          information = {
            note = ''
              Handy is installed via Homebrew. After first launch:
              1. Grant microphone and accessibility permissions when prompted
              2. Configure your preferred keyboard shortcut in Handy Settings
              3. Use Ctrl+Option+H (or your custom shortcut) to toggle transcription
            '';
          };
        };
      })
    ]
  );
}
