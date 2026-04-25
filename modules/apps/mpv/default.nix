{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.apps.mpv;
in
{
  options.apps.mpv = {
    enable = lib.mkEnableOption "Enable MPV video player";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.mpv ];

    home-manager.users.${username} = _: {
      home.file.".config/mpv/scripts/camtoggle-aspect.lua".text = ''
        function on_fullscreen_change(name, value)
            if value == true then
                -- 16:9 crop when fullscreen
                mp.set_property("vf", "crop=ih/9*16:ih")
            else
                -- Square crop when windowed
                mp.set_property("vf", "crop=in_h:in_h")
            end
        end

        mp.observe_property("fullscreen", "bool", on_fullscreen_change)
      '';
    };
  };
}
