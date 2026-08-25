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

  sketchybarPackage = pkgs.sketchybar.overrideAttrs (_: {
    version = "2.24.0";
    src = pkgs.fetchFromGitHub {
      owner = "FelixKratz";
      repo = "SketchyBar";
      rev = "v2.24.0";
      hash = "sha256-5tyc/yYzdV/3JTtujuj7le/14XkC7TlN/nZg7tOZsNg=";
    };
  });

  toSketchyColor = hex: "0xff${lib.removePrefix "#" hex}";

  theme = pkgs.replaceVars ./config/theme.sh.in {
    inherit (desktopBar.geometry)
      barHeight
      controlHeight
      controlMinWidth
      indicatorHeight
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
        label="●" \
        label.drawing=off \
        label.font="$PRIMARY_FONT:Regular:6.0" \
        label.y_offset=7 \
        label.width=6 \
        label.padding_left=-6 \
        label.padding_right=0 \
        icon.background.height="$INDICATOR_HEIGHT" \
        icon.background.corner_radius=0 \
        icon.background.y_offset=-9 \
        width="$CONTROL_MIN_WIDTH" \
        click_script="aerospace workspace ${toString workspace.id}"
  '') desktopBar.workspaces;

  # Alias creation is reversed because SketchyBar prepends right-side items.
  traySetup = lib.concatMapStringsSep "\n" (alias: ''
    if sketchybar --query default_menu_items 2>/dev/null \
      | /usr/bin/grep -Fq ${lib.escapeShellArg "\"${alias.name}"}; then
      sketchybar --add alias ${lib.escapeShellArg alias.name} right \
        --set ${lib.escapeShellArg alias.name} \
          padding_left="$ITEM_GAP" \
          padding_right=0 \
          background.drawing=off \
          click_script=${lib.escapeShellArg alias.clickCommand}
      TRAY_ITEMS+=(${lib.escapeShellArg alias.name})
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
    substituteInPlace "$out/items/power.sh" \
      --replace-fail '@vicinaeLauncher@' '/Users/${username}/.local/state/nix/profiles/home-manager/home-path/bin/vicinae-launcher'
    chmod +x "$out/sketchybarrc" "$out/plugins/"*.sh
  '';
in
{
  options.darwin.apps.sketchybar = {
    enable = lib.mkEnableOption "the rgo SketchyBar instrument rail";
    hideMenuBar = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Hide the native macOS menu bar while SketchyBar shows the instrument rail";
    };
    trayAliases = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = "Menu-extra alias reported by SketchyBar";
            };
            clickCommand = lib.mkOption {
              type = lib.types.str;
              description = "Stable native action for the mirrored icon";
            };
          };
        }
      );
      default = [
        {
          name = "Tailscale";
          clickCommand = "/usr/bin/open -a Tailscale";
        }
        {
          name = "Syncthing";
          clickCommand = "/usr/bin/open -a Syncthing";
        }
        {
          name = "Control Center,WiFi";
          clickCommand = "/usr/bin/open 'x-apple.systempreferences:com.apple.wifi-settings-extension'";
        }
        {
          name = "Control Center,Battery";
          clickCommand = "/usr/bin/open 'x-apple.systempreferences:com.apple.Battery-Settings.extension'";
        }
      ];
      description = "macOS menu-bar applications mirrored into SketchyBar with explicit click actions";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = constants.isDarwin;
          message = "darwin.apps.sketchybar is only supported on macOS";
        }
      ];

      home-manager.users.${username} = {
        programs.sketchybar = {
          enable = true;
          package = sketchybarPackage;
          config = {
            source = generatedConfig;
            recursive = true;
          };
          extraPackages = [ pkgs.nowplaying-cli ];
        };
      };
    })
    {
      # The menu bar decision applies in both states: disabling the bar restores
      # the native menu bar instead of leaving _HIHideMenuBar set from a previous
      # enable. The toggle is darwin.apps.sketchybar.hideMenuBar.
      system.defaults.NSGlobalDomain._HIHideMenuBar = cfg.enable && cfg.hideMenuBar;
    }
  ];
}
