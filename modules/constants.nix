# Reusable constants for the NixOS configuration
{ username, system }:
let
  isDarwin = builtins.match ".*-darwin" system != null;
  homeDir = if isDarwin then "/Users/${username}" else "/home/${username}";
in
{
  # Typography - used across multiple modules
  fonts = {
    primary = "JetBrainsMono Nerd Font";
    ui = "Bricolage Grotesque";
    sizes = {
      small = 10.0;
      normal = 12.0;
      large = 14.0;
    };
  };

  # Color scheme (Gruvbox) - used across multiple modules
  colors = {
    # Background colors
    bg0 = "#282828";
    bg1 = "#1d2021";
    bg2 = "#3c3836";

    # Foreground colors
    fg0 = "#ebdbb2";
    fg1 = "#a89984";
    fg2 = "#928374";

    # Gruvbox accent colors
    red = "#cc241d";
    redBright = "#fb4934";
    green = "#98971a";
    greenBright = "#b8bb26";
    yellow = "#d79921";
    yellowBright = "#fabd2f";
    blue = "#458588";
    blueBright = "#83a598";
    magenta = "#b16286";
    magentaBright = "#d3869b";
    cyan = "#689d6a";
    cyanBright = "#8ec07c";
    orange = "#d65d0e";
    orangeBright = "#fe8019";
  };

  # Display settings - used across multiple modules
  display = {
    dpi = 96;
    opacity = 0.90;
  };

  # Home directory - platform aware (Linux vs macOS)
  inherit homeDir;

  # Scripts directory - used across multiple modules
  scriptDir = "${homeDir}/.config/home/modules/scripts";
}
