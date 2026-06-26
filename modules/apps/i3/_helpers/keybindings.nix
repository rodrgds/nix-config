{ pkgs, constants }:
let
  mod = "Mod4";
  inherit (constants) scriptDir;
in
{
  "${mod}+1" = "workspace 1: ";
  "${mod}+2" = "workspace 2: ";
  "${mod}+3" = "workspace 3: ";
  "${mod}+4" = "workspace 4: ";
  "${mod}+5" = "workspace 5: ";
  "${mod}+6" = "workspace 6: ";
  "${mod}+7" = "workspace 7";
  "${mod}+8" = "workspace 8";
  "${mod}+9" = "workspace 9";
  "${mod}+0" = "workspace 10: ";

  "${mod}+Shift+1" = "move container to workspace 1: ";
  "${mod}+Shift+2" = "move container to workspace 2: ";
  "${mod}+Shift+3" = "move container to workspace 3: ";
  "${mod}+Shift+4" = "move container to workspace 4: ";
  "${mod}+Shift+5" = "move container to workspace 5: ";
  "${mod}+Shift+6" = "move container to workspace 6: ";
  "${mod}+Shift+7" = "move container to workspace 7";
  "${mod}+Shift+8" = "move container to workspace 8";
  "${mod}+Shift+9" = "move container to workspace 9";
  "${mod}+Shift+0" = "move container to workspace 10: ";

  "${mod}+q" = "kill";
  "${mod}+l" = "exec bash ${scriptDir}/show_random_wall.sh && i3lock";
  "${mod}+Shift+c" = "reload";
  "${mod}+Shift+r" = "restart";
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
  "${mod}+Shift+s" = "exec --no-startup-id flameshot gui";
  "${mod}+m" = "exec bash ${scriptDir}/toggle_keyboard_layout.sh";
  "${mod}+Shift+t" = "exec normcap -l por";
  "${mod}+p" = "exec bash ${scriptDir}/get_ai_answer.sh";
  "${mod}+c" = "exec --no-startup-id bash ${scriptDir}/camtoggle.sh";
  "${mod}+Shift+q" =
    "exec --no-startup-id flameshot gui && bash ${scriptDir}/twitter_reply.py && notify-send 'Reply copied!'";
  "${mod}+Shift+w" =
    "exec --no-startup-id bash ${scriptDir}/code_to_image.sh && notify-send 'Image generated and copied!'";
  "${mod}+w" = "exec microsoft-edge";
  "${mod}+n" = "exec thunar";
  "${mod}+period" = "exec --no-startup-id vicinae 'vicinae://launch/core/search-emojis'";
  "Print" =
    "exec scrot ~/%Y-%m-%d-%T-screenshot.png && notify-send 'Screenshot saved to ~/$(date +%Y-%m-%d-%T)-screenshot.png'";
  "${mod}+d" = "exec vicinae toggle";
  # "${mod}+Shift+h" = "exec handy --toggle-transcription";
}
