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
    mono = "JetBrainsMono Nerd Font";
    ui = "Geist";
    sizes = {
      small = 10.0;
      normal = 12.0;
      large = 14.0;
    };
  };

  # Color scheme (Flexoki)
  colors = {
    # Background colors (Flexoki dark theme)
    bg0 = "#100F0F"; # black
    bg1 = "#1C1B1A"; # base-950
    bg2 = "#282726"; # base-900

    # Foreground colors (Flexoki dark theme)
    fg0 = "#CECDC3"; # base-200
    fg1 = "#6F6E69"; # base-600
    fg2 = "#575653"; # base-700

    # Flexoki accent colors (dark mode: 600 for UI, 400 for highlights)
    red = "#AF3029"; # red-600
    redBright = "#D14D41"; # red-400
    green = "#66800B"; # green-600
    greenBright = "#879A39"; # green-400
    yellow = "#AD8301"; # yellow-600
    yellowBright = "#D0A215"; # yellow-400
    blue = "#205EA6"; # blue-600
    blueBright = "#4385BE"; # blue-400
    magenta = "#A02F6F"; # magenta-600
    magentaBright = "#CE5D97"; # magenta-400
    cyan = "#24837B"; # cyan-600
    cyanBright = "#3AA99F"; # cyan-400
    orange = "#BC5215"; # orange-600
    orangeBright = "#DA702C"; # orange-400
    purple = "#5E409D"; # purple-600
  };

  # Display settings
  display = {
    dpi = 96;
    opacity = 0.92;
  };

  inherit isDarwin isLinux;

  inherit homeDir;

  scriptDir = "${homeDir}/.config/home/modules/scripts";
  moduleDir = "${homeDir}/.config/home/modules";

  sshPublicKeys = {
    rgo-laptop = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDC/Jjb+539tc/YzVy7RqNVv8YoPlO8d+BPbvEnJkNQ6 rgo@rgo-laptop";
    rgo-desktop = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINK2FzW5OZRry66mr9+mpoaoT/506XUv7D9agrcCwZkl rgo@rgopc";
    rgo-termix = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAU8WdT+rpucAPIhHEw6pmj4VGJyAIh21EFDLJ5+6HWn";
    hermes-nas = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFyn3LXPT/xfYPq7/YHH6yNjjjzTCvvKKEfxi5t68XOQ hermes@NAS";
  };
}
