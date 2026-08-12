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
  };

  vicinaePackage = inputs.vicinae.packages.${pkgs.stdenv.hostPlatform.system}.default;
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
