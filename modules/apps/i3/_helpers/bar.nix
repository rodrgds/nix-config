{ pkgs, constants }:
[
  {
    position = "bottom";
    statusCommand = "bumblebee-status -t gruvbox-powerline -m disk memory cpu layout shortcut uptime date time -p shortcut.cmds='${constants.scriptDir}/toggle_keyboard_layout.sh;${constants.scriptDir}/toggle_sound_device.sh;${constants.scriptDir}/1monitor.sh;${constants.scriptDir}/fullres.sh' shortcut.labels=' ; ; ; ' time.format=' %H:%M' date.format=' %a, %b %d' disk.format=' {left}' memory.format='{percent:.2f}%' cpu.format=' {:.0f}%' layout.format='a{variant}' uptime.format=' {hours}:{mins:02d}'";
    fonts = {
      names = [
        "JetBrainsMono Nerd Font"
        "Font Awesome 6 Free"
      ];
      size = 12.0;
    };
  }
]
