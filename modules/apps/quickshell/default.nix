{
  lib,
  config,
  pkgs,
  inputs,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.quickshell;
  desktopBar = import ../../desktop-bar.nix { inherit constants; };

  themeQml = pkgs.replaceVars ./config/Theme.qml.in {
    inherit (constants.colors)
      bg0
      bg1
      bg2
      fg0
      red
      redBright
      greenBright
      yellowBright
      orange
      orangeBright
      ;
    primaryFont = constants.fonts.primary;
    uiFont = constants.fonts.ui;
    inherit (desktopBar) foregroundMuted;
    workspaceSpecs = builtins.toJSON desktopBar.workspaces;
    inherit (desktopBar.geometry)
      barHeight
      cornerRadius
      controlHeight
      controlMinWidth
      indicatorHeight
      itemGap
      outerGutter
      ;
  };

  vicinaePackage = inputs.vicinae.packages.${pkgs.stdenv.hostPlatform.system}.default;
  askpass = pkgs.writeShellApplication {
    name = "rgo-sudo-askpass";
    text = ''
      if [[ -z "''${XDG_RUNTIME_DIR:-}" ]]; then
        echo "rgo-sudo-askpass: XDG_RUNTIME_DIR is not set" >&2
        exit 1
      fi

      umask 077
      request_root="$XDG_RUNTIME_DIR/rgo-sudo-askpass"
      ${pkgs.coreutils}/bin/mkdir -p "$request_root"
      ${pkgs.coreutils}/bin/chmod 700 "$request_root"
      request_dir="$(${pkgs.coreutils}/bin/mktemp -d "$request_root/request.XXXXXX")"
      socket_path="$request_dir/reply.sock"

      cleanup() {
        ${pkgs.coreutils}/bin/rm -rf -- "$request_dir"
      }
      trap cleanup EXIT HUP INT TERM

      command="$(${pkgs.procps}/bin/ps -o args= -p "$PPID" 2>/dev/null || true)"

      response="$(
        ${pkgs.socat}/bin/socat -u -T 300 UNIX-LISTEN:"$socket_path",mode=0600 STDOUT &
        listener_pid=$!

        for _ in {1..100}; do
          [[ -S "$socket_path" ]] && break
          ${pkgs.coreutils}/bin/sleep 0.01
        done

        if [[ ! -S "$socket_path" ]]; then
          echo "rgo-sudo-askpass: failed to open response socket" >&2
          kill "$listener_pid" 2>/dev/null || true
          exit 1
        fi

        accepted="$(${pkgs.quickshell}/bin/quickshell -c rgo-bar ipc call askpass request \
          "$socket_path" "$command")" || {
          kill "$listener_pid" 2>/dev/null || true
          exit 1
        }

        if [[ "$accepted" != "true" ]]; then
          kill "$listener_pid" 2>/dev/null || true
          exit 1
        fi

        wait "$listener_pid"
      )" || exit 1

      if [[ "''${response:0:1}" != "A" ]]; then
        exit 1
      fi

      printf '%s\n' "''${response:1}"
    '';
  };
  runtimeQml = pkgs.replaceVars ./config/Runtime.qml.in {
    bashPath = lib.getExe pkgs.bash;
    dfPath = lib.getExe' pkgs.coreutils "df";
    hyprctlPath = lib.getExe' pkgs.hyprland "hyprctl";
    pavucontrolPath = lib.getExe pkgs.pavucontrol;
    psPath = lib.getExe' pkgs.procps "ps";
    vicinaePath = lib.getExe vicinaePackage;
    inherit (constants) scriptDir;
  };

  quickshellConfig = pkgs.runCommandLocal "rgo-quickshell-config" { } ''
    mkdir -p "$out"
    cp -r ${./config}/. "$out/"
    rm "$out/Theme.qml.in" "$out/Runtime.qml.in"
    cp ${themeQml} "$out/Theme.qml"
    cp ${runtimeQml} "$out/Runtime.qml"
  '';

in
{
  options.apps.quickshell = {
    enable = lib.mkEnableOption "Enable the rgo Quickshell bar";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = constants.isLinux;
        message = "apps.quickshell is only supported on Linux";
      }
    ];

    home-manager.users.${username} = {
      programs.quickshell = {
        enable = true;
        package = pkgs.quickshell;
        configs."rgo-bar" = quickshellConfig;
        activeConfig = "rgo-bar";
        systemd = {
          enable = true;
          target = "graphical-session.target";
        };
      };

      home = {
        packages = [ askpass ];
        sessionVariables.SUDO_ASKPASS = lib.getExe askpass;
      };

      # UWSM exposes graphical-session.target for session-scoped services.
      # Match the UWSM desktop condition so this service only enters Hyprland.
      systemd.user.services.quickshell = {
        Unit.PartOf = [ "graphical-session.target" ];
        Service = {
          ExecCondition = "${pkgs.systemd}/lib/systemd/systemd-xdg-autostart-condition 'Hyprland' ''";
          Type = "exec";
          Restart = lib.mkForce "on-failure";
          RestartSec = "2s";
          Slice = "app-graphical.slice";
          Environment = [ "QT_QPA_PLATFORM=wayland" ];
        };
      };
    };
  };
}
