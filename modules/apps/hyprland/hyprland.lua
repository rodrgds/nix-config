-- Hyprland 0.55+ Lua configuration. Tokens are replaced by the Nix module.

local mod = "SUPER"
local scriptDir = "@scriptDir@"

-- DP-1 is the left gaming monitor; HDMI-A-1 sits directly to its right.
hl.monitor({
  output = "DP-1",
  mode = "1920x1080@144",
  position = "0x0",
  scale = 1,
})
hl.monitor({
  output = "HDMI-A-1",
  mode = "1920x1080@144",
  position = "1920x0",
  scale = 1,
})
hl.monitor({
  output = "",
  mode = "preferred",
  position = "auto",
  scale = 1,
})

hl.config({
  general = {
    gaps_in = 0,
    gaps_out = 0,
    border_size = 2,
    col = {
      active_border = "rgb(@orangeBright@)",
      inactive_border = "rgb(@bg2@)",
    },
    resize_on_border = true,
    allow_tearing = false,
    layout = "dwindle",
  },
  decoration = {
    rounding = 0,
    active_opacity = 1,
    inactive_opacity = 1,
    shadow = { enabled = false },
    blur = { enabled = false },
  },
  animations = {
    enabled = true,
    workspace_wraparound = true,
  },
  input = {
    kb_layout = "us,pt",
    follow_mouse = 1,
    sensitivity = -0.35,
    touchpad = { natural_scroll = false },
  },
  dwindle = {
    preserve_split = true,
    smart_resizing = true,
  },
  group = {
    insert_after_current = true,
    groupbar = {
      enabled = true,
      font_family = "@uiFont@",
      font_size = 10,
      gradients = false,
      height = 18,
      indicator_height = 2,
      col = {
        active = "rgb(@orangeBright@)",
        inactive = "rgb(@bg2@)",
      },
      text_color = "rgb(@fg0@)",
      text_color_inactive = "rgb(@fg1@)",
    },
  },
  misc = {
    background_color = "rgb(@bg0@)",
    disable_hyprland_logo = true,
    force_default_wallpaper = 0,
    -- The physical outputs run XRGB8888. Keeping portal capture at the same
    -- 8-bit depth avoids NVIDIA/Electron format negotiation failures.
    screencopy_force_8b = true,
    vrr = 0,
  },
  render = {
    direct_scanout = 0,
  },
  cursor = {
    warp_on_change_workspace = true,
  },
  binds = {
    allow_pin_fullscreen = true,
  },
  xwayland = {
    enabled = true,
  },
})

-- Motion thesis: workspace changes communicate direction, while window open,
-- close, move, and resize transitions stay quick enough to remain interruptible.
hl.curve("rgoEase", {
  type = "bezier",
  points = { { 0.22, 1.0 }, { 0.36, 1.0 } },
})
hl.curve("rgoSpring", {
  type = "spring",
  mass = 1.0,
  stiffness = 190.0,
  dampening = 24.0,
})
hl.animation({ leaf = "windowsIn", enabled = true, speed = 2.2, bezier = "rgoEase", style = "popin 92%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.6, bezier = "rgoEase", style = "popin 94%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 2.8, spring = "rgoSpring" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 3.2, spring = "rgoSpring", style = "slidefade 18%" })
hl.animation({ leaf = "fade", enabled = true, speed = 1.8, bezier = "rgoEase" })
hl.animation({ leaf = "border", enabled = true, speed = 1.8, bezier = "rgoEase" })
hl.animation({ leaf = "layers", enabled = true, speed = 2.0, bezier = "rgoEase", style = "fade" })

-- Preserve the established output assignments. Workspace 6 is explicitly on
-- DP-1 so CS2 opens on the left gaming display.
hl.workspace_rule({ workspace = "1", monitor = "DP-1", default = true, persistent = true })
hl.workspace_rule({ workspace = "2", monitor = "HDMI-A-1", default = true, persistent = true })
hl.workspace_rule({ workspace = "3", monitor = "DP-1", persistent = true })
hl.workspace_rule({ workspace = "5", monitor = "HDMI-A-1", persistent = true })
hl.workspace_rule({ workspace = "6", monitor = "DP-1", persistent = true })

local function routeClass(name, class, workspace)
  hl.window_rule({
    name = name,
    -- Hyprland's RE2 matching is against the complete class value. Wrapping
    -- the familiar i3 fragments also catches native IDs such as
    -- com.mitchellh.ghostty.
    match = { class = "(?i).*" .. class .. ".*" },
    workspace = tostring(workspace) .. " silent",
  })
end

routeClass("terminal-ghostty", "ghostty", 1)
routeClass("terminal-alacritty", "alacritty", 1)
routeClass("terminal-zed", "dev[.]zed[.]Zed", 1)
routeClass("terminal-cursor", "cursor", 1)
routeClass("terminal-code", "code", 1)

routeClass("web-firefox", "firefox", 2)
routeClass("web-zen", "zen", 2)
routeClass("web-zen-browser", "zen-browser", 2)
routeClass("web-edge-dev", "microsoft-edge-dev", 2)
routeClass("web-edge", "microsoft-edge", 2)
routeClass("web-chrome", "google-chrome", 2)
routeClass("web-chromium", "chromium", 2)
routeClass("web-navigator", "Navigator", 2)
routeClass("web-floorp", "floorp", 2)
routeClass("web-vivaldi", "vivaldi", 2)
routeClass("web-brave", "brave", 2)

routeClass("files-thunar", "thunar", 3)
routeClass("personal-thunderbird", "thunderbird", 4)
routeClass("personal-obsidian", "obsidian", 4)

routeClass("chat-telegram", "(TelegramDesktop|org[.]telegram[.]desktop)", 5)
routeClass("chat-teamspeak", "TeamSpeak", 5)
routeClass("chat-discord", "discord", 5)
routeClass("chat-vesktop", "vesktop", 5)
routeClass("chat-beeper", "beeper", 5)

routeClass("gaming-steam", "steam", 6)
hl.window_rule({
  name = "music-spotify",
  match = { class = "(?i).*spotify.*" },
  workspace = "special:music silent",
})
hl.window_rule({
  name = "music-youtube",
  match = { title = "(?i).*YouTube Music.*" },
  workspace = "special:music silent",
})

hl.window_rule({
  name = "camera-preview",
  match = { class = "mpv", title = "Camera Preview" },
  float = true,
  pin = true,
  -- Both displays are fixed 1920x1080 at scale 1. Explicit monitor-local
  -- coordinates avoid Hyprland 0.55's incorrect expression evaluation here.
  size = { 400, 400 },
  move = { 1508, 668 },
  keep_aspect_ratio = true,
  no_max_size = true,
  sync_fullscreen = true,
})
hl.window_rule({
  name = "vicinae-launcher",
  match = { class = "(?i).*vicinae.*" },
  float = true,
  center = true,
})
hl.window_rule({
  name = "cs2-gaming",
  match = { class = "(?i)cs2" },
  workspace = "6 silent",
  fullscreen = true,
  idle_inhibit = "fullscreen",
  confine_pointer = true,
  content = "game",
  no_anim = true,
})
-- Workspace 10's music role is now owned by the music scratchpad.
for i = 1, 9 do
  local key = i
  hl.bind(mod .. " + " .. key, hl.dsp.focus({ workspace = i }))
  hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i, follow = false }))
end

hl.bind(mod .. " + Q", hl.dsp.window.close())
hl.bind(mod .. " + Return", hl.dsp.exec_cmd("ghostty"))
hl.bind(mod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind(mod .. " + space", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + G", hl.dsp.group.toggle())
hl.bind(mod .. " + E", hl.dsp.layout("togglesplit"))
hl.bind(mod .. " + H", hl.dsp.layout("preselect r"))
hl.bind(mod .. " + V", hl.dsp.layout("preselect d"))

local directions = {
  J = "left",
  K = "down",
  B = "up",
  O = "right",
  left = "left",
  down = "down",
  up = "up",
  right = "right",
}
for key, direction in pairs(directions) do
  hl.bind(mod .. " + " .. key, hl.dsp.focus({ direction = direction }))
  hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ direction = direction }))
end

hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind(mod .. " + Caps_Lock", hl.dsp.workspace.toggle_special("music"))
hl.bind(mod .. " + L", hl.dsp.exec_cmd("bash -c 'bash " .. scriptDir .. "/show_random_wall.sh || true; exec hyprlock'"))
hl.bind(mod .. " + SHIFT + C", hl.dsp.exec_cmd("@hyprpicker@ -a -f hex -r"))
hl.bind(mod .. " + SHIFT + R", hl.dsp.exec_cmd("hyprctl reload && systemctl --user try-restart quickshell.service"))
hl.bind(mod .. " + SHIFT + S", hl.dsp.exec_cmd("bash " .. scriptDir .. "/screenshot.sh region"))
hl.bind("Print", hl.dsp.exec_cmd("bash " .. scriptDir .. "/screenshot.sh full"))
hl.bind(mod .. " + M", hl.dsp.exec_cmd("bash " .. scriptDir .. "/toggle_keyboard_layout.sh"))
hl.bind(mod .. " + SHIFT + T", hl.dsp.exec_cmd("normcap -l por"))
hl.bind(mod .. " + C", hl.dsp.exec_cmd("bash " .. scriptDir .. "/camtoggle.sh"))
hl.bind(mod .. " + SHIFT + Q", hl.dsp.exec_cmd("bash " .. scriptDir .. "/screenshot.sh region && python3 " .. scriptDir .. "/twitter_reply.py && notify-send 'Reply copied!'"))
hl.bind(mod .. " + SHIFT + W", hl.dsp.exec_cmd("bash " .. scriptDir .. "/code_to_image.sh && notify-send 'Image generated and copied!'"))
hl.bind(mod .. " + W", hl.dsp.exec_cmd("brave"))
hl.bind(mod .. " + N", hl.dsp.exec_cmd("thunar"))
hl.bind(mod .. " + period", hl.dsp.exec_cmd("vicinae 'vicinae://launch/core/search-emojis'"))
hl.bind(mod .. " + D", hl.dsp.exec_cmd("vicinae toggle"))

-- Handy documents compositor-owned shortcuts for Wayland. The second process
-- forwards the command to the already-running hidden service and exits.
hl.bind("CTRL + space", hl.dsp.exec_cmd("handy --toggle-transcription"))
-- Dunst removed its own keyboard-grab shortcuts; keep the remaining actions
-- in the compositor without taking Handy's primary shortcut.
hl.bind("CTRL + SHIFT + space", hl.dsp.exec_cmd("dunstctl close-all"))
hl.bind("CTRL + grave", hl.dsp.exec_cmd("dunstctl history-pop"))
hl.bind("CTRL + SHIFT + period", hl.dsp.exec_cmd("dunstctl context"))

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
