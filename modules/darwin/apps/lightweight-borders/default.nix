{
  lib,
  config,
  inputs,
  username,
  constants,
  ...
}:
let
  cfg = config.darwin.apps.lightweight-borders;
  homeDir = "/Users/${username}";
  source = "${inputs.omacosy}/helper/borders.swift";
  sourceRevision = inputs.omacosy.rev or "9e60b396b5e48a862bcb46bca5f2b13a63a822aa";
  borderBuildId = builtins.hashString "sha256" "${sourceRevision}:rgo-borders-v1";
  binary = "${homeDir}/.local/libexec/rgo-borders";
  toBorderColor = hex: "0xff${lib.removePrefix "#" hex}";
in
{
  options.darwin.apps.lightweight-borders = {
    enable = lib.mkEnableOption "the lightweight focused-window border";
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
    # change only its local file paths before compiling it with Apple's SDK.
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

              /usr/bin/sed \
                -e 's|.config/omacosy/borders.conf|.config/rgo-desktop/borders.conf|g' \
                -e 's|.config/omarchy/current/theme/borders.sh|.config/rgo-desktop/borders-theme.sh|g' \
                -e 's|.config/omarchy/current|.config/rgo-desktop|g' \
                -e 's|/tmp/omacosy-ws-switch|/tmp/rgo-aerospace-ws-switch|g' \
                ${source} > "$build_dir/borders.swift"

              /usr/bin/xcrun swiftc -O \
                -F /System/Library/PrivateFrameworks \
                -framework SkyLight \
                -o "$build_dir/rgo-borders" \
                "$build_dir/borders.swift"
              /usr/bin/codesign --force --sign - --identifier dev.rgo.borders "$build_dir/rgo-borders"
              /bin/mv "$build_dir/rgo-borders" ${binary}
            printf '%s\n' ${lib.escapeShellArg borderBuildId} > "$stamp"
            fi
        '';
      };

    launchd.user.agents.rgo-borders.serviceConfig = {
      Label = "dev.rgo.borders";
      ProgramArguments = [ binary ];
      KeepAlive = true;
      RunAtLoad = true;
      ProcessType = "Interactive";
      StandardOutPath = "/tmp/rgo-borders.stdout.log";
      StandardErrorPath = "/tmp/rgo-borders.stderr.log";
    };
  };
}
