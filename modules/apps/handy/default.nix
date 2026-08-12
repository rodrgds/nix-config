{
  lib,
  config,
  pkgs,
  constants,
  ...
}:
let
  cfg = config.apps.handy;
  inherit (constants) isLinux isDarwin;
in
{
  options.apps.handy = {
    enable = lib.mkEnableOption "Enable Handy";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        # Handy delegates text insertion to wtype in native Wayland sessions.
        environment.systemPackages = [
          pkgs.handy
          pkgs.wtype
        ];
        environment.sessionVariables = {
          WEBKIT_DISABLE_DMABUF_RENDERER = "1";
        };
      })
      (lib.optionalAttrs isDarwin {
        homebrew.casks = [ "handy" ];

        launchd.user.agents.handy = {
          serviceConfig = {
            Label = "com.user.handy";
            ProgramArguments = [
              "/opt/homebrew/bin/handy"
              "--start-hidden"
              "--no-tray"
            ];
            KeepAlive = true;
            RunAtLoad = true;
            StandardOutPath = "/tmp/handy.log";
            StandardErrorPath = "/tmp/handy.error.log";
          };
        };
      })
    ]
  );
}
