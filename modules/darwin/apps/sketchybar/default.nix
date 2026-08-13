{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.darwin.apps.sketchybar;
  desktopBar = import ../../../desktop-bar.nix { inherit constants; };

  toSketchyColor = hex: "0xff${lib.removePrefix "#" hex}";

  theme = pkgs.replaceVars ./config/theme.sh.in {
    inherit (desktopBar.geometry)
      barHeight
      controlHeight
      controlMinWidth
      outerGutter
      itemGap
      cornerRadius
      ;
    primaryFont = desktopBar.fonts.primary;
    bg0 = toSketchyColor desktopBar.colors.bg0;
    bg1 = toSketchyColor desktopBar.colors.bg1;
    bg2 = toSketchyColor desktopBar.colors.bg2;
    fg0 = toSketchyColor desktopBar.colors.fg0;
    fgMuted = toSketchyColor desktopBar.foregroundMuted;
    redBright = toSketchyColor desktopBar.colors.redBright;
    yellowBright = toSketchyColor desktopBar.colors.yellowBright;
    orange = toSketchyColor desktopBar.colors.orange;
    orangeBright = toSketchyColor desktopBar.colors.orangeBright;
  };

  workspaceSetup = lib.concatMapStringsSep "\n" (workspace: ''
    sketchybar --add item "space.${toString workspace.id}" left \
      --set "space.${toString workspace.id}" \
        icon="${if workspace.icon == "" then toString workspace.id else workspace.icon}" \
        label="" \
        width="$CONTROL_MIN_WIDTH" \
        click_script="aerospace workspace ${toString workspace.id}" \
        script="$PLUGIN_DIR/workspace.sh ${toString workspace.id}" \
        update_freq=5 \
      --subscribe "space.${toString workspace.id}" \
        aerospace_workspace_change front_app_switched mouse.entered mouse.exited
  '') desktopBar.workspaces;

  # Alias creation is reversed because SketchyBar prepends right-side items.
  traySetup = lib.concatMapStringsSep "\n" (application: ''
    if sketchybar --query default_menu_items 2>/dev/null \
      | /usr/bin/grep -Fq ${lib.escapeShellArg "\"${application}\""}; then
      sketchybar --add alias ${lib.escapeShellArg application} right \
        --set ${lib.escapeShellArg application} \
          padding_left="$ITEM_GAP" \
          padding_right=0 \
          background.drawing=off
    fi
  '') (lib.reverseList cfg.trayAliases);

  generatedConfig = pkgs.runCommandLocal "rgo-sketchybar-config" { } ''
    cp -R ${./config} "$out"
    chmod -R u+w "$out"
    rm "$out/theme.sh.in" "$out/workspaces.sh.in"
    cp ${theme} "$out/theme.sh"
    cp ${
      pkgs.replaceVars ./config/workspaces.sh.in { inherit workspaceSetup; }
    } "$out/items/workspaces.sh"
    cp ${pkgs.replaceVars ./config/tray.sh.in { inherit traySetup; }} "$out/items/tray.sh"
    chmod +x "$out/sketchybarrc" "$out/plugins/"*.sh
  '';
in
{
  options.darwin.apps.sketchybar = {
    enable = lib.mkEnableOption "the rgo SketchyBar instrument rail";
    trayAliases = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "Tailscale"
        "Syncthing"
        "Control Center,WiFi"
        "Control Center,Battery"
      ];
      description = "macOS menu-bar applications mirrored into SketchyBar";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = constants.isDarwin;
        message = "darwin.apps.sketchybar is only supported on macOS";
      }
    ];

    # SketchyBar owns the visible rail; reveal Apple's menu bar at the screen
    # edge when its native status items are needed.
    system.defaults.NSGlobalDomain._HIHideMenuBar = true;

    home-manager.users.${username}.programs.sketchybar = {
      enable = true;
      config = {
        source = generatedConfig;
        recursive = true;
      };
      extraPackages = [ pkgs.nowplaying-cli ];
    };
  };
}
