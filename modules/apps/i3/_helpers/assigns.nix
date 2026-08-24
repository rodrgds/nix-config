_:
let
  workspaces = (import ./workspaces.nix).names;
in
{
  "${workspaces.terminal}" = [
    { class = "(?i)ghostty"; }
    { class = "(?i)alacritty"; }
    { class = "(?i)dev.zed.Zed"; }
    { class = "(?i)cursor"; }
    { class = "(?i)code"; }
  ];
  "${workspaces.web}" = [
    { class = "(?i)firefox"; }
    { class = "(?i)zen"; }
    { class = "(?i)zen-browser"; }
    { class = "(?i)microsoft-edge-dev"; }
    { class = "(?i)microsoft-edge"; }
    { class = "(?i)google-chrome"; }
    { class = "(?i)chrome"; }
    { class = "(?i)chromium"; }
    { class = "(?i)Navigator"; }
    { class = "(?i)floorp"; }
    { class = "(?i)vivaldi"; }
    { class = "(?i)brave"; }
  ];
  "${workspaces.files}" = [ { class = "(?i)thunar"; } ];
  "${workspaces.personal}" = [
    { class = "(?i)thunderbird"; }
    { class = "(?i)obsidian"; }
  ];
  "${workspaces.chat}" = [
    { class = "(?i)TelegramDesktop"; }
    { class = "(?i)TeamSpeak"; }
    { class = "(?i)discord"; }
    { class = "(?i)vesktop"; }
    { class = "(?i)beeper"; }
  ];
  "${workspaces.gaming}" = [
    { class = "(?i)steam"; }
    { class = "(?i)cs2"; }
  ];
  "${workspaces.music}" = [
    { class = "(?i)spotify"; }
    { title = "(?i)YouTube Music"; }
  ];
}
