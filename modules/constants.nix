# Reusable constants for the NixOS configuration
{ username, system }:
let
  isDarwin = builtins.match ".*-darwin" system != null;
  isLinux = builtins.match ".*-linux" system != null;
  homeDir = if isDarwin then "/Users/${username}" else "/home/${username}";
in
{
  # User information
  fullname = "Rodrigo Dias";
  email = "me@rgo.pt";

  # Typography
  fonts = {
    primary = "JetBrainsMono Nerd Font";
    ui = "Bricolage Grotesque";
    sizes = {
      small = 10.0;
      normal = 12.0;
      large = 14.0;
    };
  };

  # Color scheme (Gruvbox)
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

  # Display settings
  display = {
    dpi = 96;
    opacity = 0.90;
  };

  inherit isDarwin isLinux;

  inherit homeDir;

  scriptDir = "${homeDir}/.config/home/modules/scripts";
  moduleDir = "${homeDir}/.config/home/modules";

  sshPublicKeys = {
    rgo-laptop = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDC/Jjb+539tc/YzVy7RqNVv8YoPlO8d+BPbvEnJkNQ6 rgo@rgo-laptop";
    rgopc = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINK2FzW5OZRry66mr9+mpoaoT/506XUv7D9agrcCwZkl rgo@rgopc";
  };
}
