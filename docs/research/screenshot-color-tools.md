# Screenshot annotation and color-picker tools

## Recommendation

Use a per-platform stack:

- macOS: [Shottr](https://shottr.cc/) for capture and annotation, plus [Pika](https://github.com/superhighfives/pika) for color picking.
- NixOS with Hyprland: [grim](https://sr.ht/~emersion/grim/) and [slurp](https://github.com/emersion/slurp) for capture, [Satty](https://github.com/Satty-org/Satty) for annotation, and [Hyprpicker](https://github.com/hyprwm/hyprpicker) for color picking.

This gives each shortcut a direct command and uses the platform-native capture path. No evaluated cross-platform app is as reliable on both macOS and Hyprland.

## Commands

| Shortcut | Platform | Command |
|---|---|---|
| Option+Shift+S | macOS | `open 'shottr://grab/area?then=edit'` |
| Option+Shift+C | macOS | `open 'pika://pick/foreground/hex'` |
| Option+Shift+T | macOS | `open 'shottr://ocr'` |
| Super+Shift+S | Hyprland | `grim -g "$(slurp)" -t ppm - \| satty --filename - --fullscreen --copy-command wl-copy` |
| Super+Shift+C | Hyprland | `hyprpicker --autocopy --format hex` |
| Super+Shift+T | Hyprland | `normcap -l por` |

Shottr documents the `then=edit` action and `shottr://ocr` command in its [URL scheme reference](https://shottr.cc/kb/urlschemes). Pika documents its picker URL in its [URL trigger reference](https://superhighfives.com/pika/help). Satty documents the `grim`, `slurp`, and Satty pipeline in its [README](https://github.com/Satty-org/Satty). Hyprpicker documents automatic clipboard copy in the [Hyprland reference](https://wiki.hypr.land/Hypr-Ecosystem/hyprpicker/). NormCap documents automatic clipboard output in its [repository](https://github.com/dynobo/normcap).

## Why these tools

### macOS

Shottr provides arrows, shapes, text, drawing, highlighting, blur, crop, spotlight, measurement, scrolling capture, and OCR. Homebrew packages it as the `shottr` cask. It can be used without paying, with occasional reminders. Its terms require a paid license for commercial use. Shottr requires Screen Recording permission. See its [product page](https://shottr.cc/), [terms](https://shottr.cc/kb/terms), and [permission guidance](https://shottr.cc/kb/faq).

Pika is a maintained native MIT-licensed color tool. It supports Hex, RGB, HSB, HSL, LAB, OpenGL, and OKLCH, plus URL automation and automatic copy after picking. Homebrew packages it as the `pika` cask. See the [Pika repository](https://github.com/superhighfives/pika) and [Homebrew cask](https://formulae.brew.sh/cask/pika).

### NixOS and Hyprland

Satty is an MPL-2.0 annotation tool built for wlroots compositors, including Hyprland. It provides crop, line, arrow, rectangle, ellipse, text, marker, blur, highlight, and brush tools. It accepts a captured image on standard input, so the compositor-specific capture stays in grim and slurp. See the [Satty repository](https://github.com/Satty-org/Satty) and [nixpkgs package](https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/by-name/sa/satty/package.nix).

Hyprpicker is maintained by the Hyprland project. It provides a magnified picker, multiple output formats, fractional-scaling support, and direct clipboard copy through `wl-copy`. See the [Hyprpicker repository](https://github.com/hyprwm/hyprpicker) and [nixpkgs package](https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/by-name/hy/hyprpicker/package.nix).

## Alternatives considered

- [ksnip](https://github.com/ksnip/ksnip) is the best open cross-platform fallback, but Qt is less native on macOS and its Wayland capture depends on desktop integration. The explicit grim and slurp pipeline is more predictable on Hyprland.
- [Snipaste](https://www.snipaste.com/) is capable on both platforms, but it is proprietary and its free tier is limited to personal use.
- [Swappy](https://github.com/jtheoof/swappy) is a good Wayland annotator, but Satty has a broader tool set and more configurable copy and exit actions.
- [CleanShot X](https://cleanshot.com/) is the most polished macOS option, but it costs more and does not improve the Linux side.
- Apple Digital Color Meter does not expose a command that immediately picks and copies a color. Pika provides the required URL automation.
- Homebrew marks Pixel Picker as deprecated because it does not pass Gatekeeper checks.

## Manual permission

After installation, grant Shottr Screen Recording access in System Settings, under Privacy & Security. Shottr ties this permission to the installed app bundle, so remove stale Shottr entries if macOS retains permission for an older copy.
