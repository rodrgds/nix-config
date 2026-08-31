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
  inherit (constants) fonts isDarwin isLinux;
  fontSize = 16;
  zedSettings = {
    auto_install_extensions.flexoki-themes = true;
    theme = {
      mode = "dark";
      dark = "Flexoki Dark";
      light = "Flexoki Light";
    };
    ui_font_family = fonts.ui;
    ui_font_size = fontSize;
    buffer_font_family = fonts.mono;
    buffer_font_size = fontSize;
    buffer_line_height = "standard";
    agent_ui_font_size = fontSize;
    agent_buffer_font_size = fontSize;
    agent.terminal_init_command = "pi";
    autosave = "on_focus_change";
    format_on_save = "on";
    features.inline_completion = false;
    terminal = {
      font_family = fonts.mono;
      font_size = fontSize;
      line_height = "standard";
    };
    telemetry = {
      metrics = false;
      diagnostics = false;
    };
  };
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
          xdg.configFile."zed/settings.json".text = builtins.toJSON zedSettings;
        };
      }
    ]
  );
}
