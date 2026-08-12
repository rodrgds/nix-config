{ pkgs, constants }:
let
  mod = "Mod4";
  inherit (constants) scriptDir;
  workspaces = (import ./workspaces.nix).names;
in
{
  "${mod}+1" = "workspace ${workspaces.terminal}";
  "${mod}+2" = "workspace ${workspaces.web}";
  "${mod}+3" = "workspace ${workspaces.files}";
  "${mod}+4" = "workspace ${workspaces.personal}";
  "${mod}+5" = "workspace ${workspaces.chat}";
  "${mod}+6" = "workspace ${workspaces.gaming}";
  "${mod}+7" = "workspace ${workspaces.seven}";
  "${mod}+8" = "workspace ${workspaces.eight}";
  "${mod}+9" = "workspace ${workspaces.nine}";
  "${mod}+0" = "workspace ${workspaces.music}";

  "${mod}+Shift+1" = "move container to workspace ${workspaces.terminal}";
  "${mod}+Shift+2" = "move container to workspace ${workspaces.web}";
  "${mod}+Shift+3" = "move container to workspace ${workspaces.files}";
  "${mod}+Shift+4" = "move container to workspace ${workspaces.personal}";
  "${mod}+Shift+5" = "move container to workspace ${workspaces.chat}";
  "${mod}+Shift+6" = "move container to workspace ${workspaces.gaming}";
  "${mod}+Shift+7" = "move container to workspace ${workspaces.seven}";
  "${mod}+Shift+8" = "move container to workspace ${workspaces.eight}";
  "${mod}+Shift+9" = "move container to workspace ${workspaces.nine}";
  "${mod}+Shift+0" = "move container to workspace ${workspaces.music}";

  "${mod}+q" = "kill";
  "${mod}+l" = "exec bash ${scriptDir}/show_random_wall.sh && i3lock";
  "${mod}+Shift+c" = "reload";
  "${mod}+Shift+r" = "exec polybar-msg cmd restart; restart";
  "${mod}+j" = "focus left";
  "${mod}+k" = "focus down";
  "${mod}+b" = "focus up";
  "${mod}+o" = "focus right";
  "${mod}+Left" = "focus left";
  "${mod}+Down" = "focus down";
  "${mod}+Up" = "focus up";
  "${mod}+Right" = "focus right";
  "${mod}+Shift+j" = "move left";
  "${mod}+Shift+k" = "move down";
  "${mod}+Shift+b" = "move up";
  "${mod}+Shift+o" = "move right";
  "${mod}+Shift+Left" = "move left";
  "${mod}+Shift+Down" = "move down";
  "${mod}+Shift+Up" = "move up";
  "${mod}+Shift+Right" = "move right";
  "${mod}+h" = "split h";
  "${mod}+v" = "split v";
  "${mod}+f" = "fullscreen toggle";
  "${mod}+s" = "layout stacking";
  "${mod}+g" = "layout tabbed";
  "${mod}+e" = "layout toggle split";
  "${mod}+space" = "floating toggle";
  "${mod}+Shift+space" = "focus mode_toggle";
  "${mod}+a" = "focus parent";

  "${mod}+Return" = "exec ghostty";
  "${mod}+Shift+s" = "exec --no-startup-id bash ${scriptDir}/screenshot.sh region";
  "${mod}+m" = "exec bash ${scriptDir}/toggle_keyboard_layout.sh";
  "${mod}+Shift+t" = "exec normcap -l por";
  "${mod}+c" = "exec --no-startup-id bash ${scriptDir}/camtoggle.sh";
  "${mod}+Shift+q" =
    "exec --no-startup-id bash ${scriptDir}/screenshot.sh region && python3 ${scriptDir}/twitter_reply.py && notify-send 'Reply copied!'";
  "${mod}+Shift+w" =
    "exec --no-startup-id bash ${scriptDir}/code_to_image.sh && notify-send 'Image generated and copied!'";
  "${mod}+w" = "exec microsoft-edge";
  "${mod}+n" = "exec thunar";
  "${mod}+period" = "exec --no-startup-id vicinae 'vicinae://launch/core/search-emojis'";
  "Print" = "exec --no-startup-id bash ${scriptDir}/screenshot.sh full";
  "${mod}+d" = "exec vicinae toggle";
  "Ctrl+space" = "exec --no-startup-id dunstctl close";
  "Ctrl+Shift+space" = "exec --no-startup-id dunstctl close-all";
  "Ctrl+grave" = "exec --no-startup-id dunstctl history-pop";
  "Ctrl+Shift+period" = "exec --no-startup-id dunstctl context";
  # "${mod}+Shift+h" = "exec handy --toggle-transcription";
}
