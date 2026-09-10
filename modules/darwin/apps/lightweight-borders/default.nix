{
  lib,
  config,
  inputs,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.darwin.apps.lightweight-borders;
  homeDir = "/Users/${username}";
  patchedSource = pkgs.applyPatches {
    name = "rgo-borders-source";
    src = inputs.omacosy;
    patches = [ ./scheduling.patch ];
  };
  source = "${patchedSource}/helper/borders.swift";
  sourceRevision = inputs.omacosy.rev or "9e60b396b5e48a862bcb46bca5f2b13a63a822aa";
  borderBuildId = builtins.hashString "sha256" (
    "${sourceRevision}:rgo-borders-v3:" + builtins.readFile ./scheduling.patch
  );
  binary = "${homeDir}/.local/libexec/rgo-borders";
  toBorderColor = hex: "0xff${lib.removePrefix "#" hex}";
in
{
  options.darwin.apps.lightweight-borders = {
    enable = lib.mkEnableOption "the lightweight focused-window border";
    diagnostics = lib.mkEnableOption "border event and rendering diagnostics in /tmp/rgo-borders.log";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = constants.isDarwin;
        message = "darwin.apps.lightweight-borders is only supported on macOS";
      }
    ];

    # omacosy's focused-window ring uses one CAShapeLayer instead of a large
    # backing surface per window. Keep the tested upstream source pinned, then
    # adapt its local paths and fullscreen detection before compiling it with
    # Apple's SDK.
    home-manager.users.${username} =
      { lib, ... }:
      {
        xdg.configFile = {
          "rgo-desktop/borders.conf".text = ''
            width=3
            gap=-1
            radius=17.5
            radius:WhatsApp=13.5
          '';
          "rgo-desktop/borders-theme.sh".text = ''
            ACTIVE_COLOR=${toBorderColor constants.colors.orange}
          '';
        };

        home.activation.compileLightweightBorders = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            set -eu

            /bin/mkdir -p ${homeDir}/.local/libexec
            stamp=${homeDir}/.local/libexec/.rgo-borders-source

          if [ ! -x ${binary} ] || [ ! -f "$stamp" ] || [ "$(/bin/cat "$stamp")" != ${lib.escapeShellArg borderBuildId} ]; then
              build_dir="$(/usr/bin/mktemp -d /tmp/rgo-borders.XXXXXX)"
              trap '/bin/rm -rf "$build_dir"' EXIT

              /bin/cp ${source} "$build_dir/borders.swift"

              /usr/bin/xcrun swiftc -O \
                -F /System/Library/PrivateFrameworks \
                -framework SkyLight \
                -o "$build_dir/rgo-borders" \
                "$build_dir/borders.swift"
              /usr/bin/codesign --force --sign - --identifier dev.rgo.borders "$build_dir/rgo-borders"
              /bin/mv "$build_dir/rgo-borders" ${binary}
            printf '%s\n' ${lib.escapeShellArg borderBuildId} > "$stamp"
            # The launchd command path is unchanged when the binary is replaced.
            # Restart an existing job so it does not keep running the old code.
            if /bin/launchctl print "gui/$(/usr/bin/id -u)/dev.rgo.borders" >/dev/null 2>&1; then
              /bin/launchctl kickstart -k "gui/$(/usr/bin/id -u)/dev.rgo.borders"
            fi
            fi
        '';
      };

    launchd.user.agents.rgo-borders.serviceConfig = {
      Label = "dev.rgo.borders";
      ProgramArguments = [ binary ] ++ lib.optional cfg.diagnostics "--diagnostics";
      KeepAlive = true;
      RunAtLoad = true;
      ProcessType = "Interactive";
      StandardOutPath = "/tmp/rgo-borders.stdout.log";
      StandardErrorPath = "/tmp/rgo-borders.stderr.log";
    };
  };
}
