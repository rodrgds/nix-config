{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.cs2;
  inherit (constants) isLinux scriptDir;
in
{
  options.apps.cs2 = {
    enable = lib.mkEnableOption "Enable CS2 configuration";
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${username} =
      { ... }:
      {
        home.file.".local/share/Steam/steamapps/common/Counter-Strike Global Offensive/game/csgo/cfg/autoexec.cfg".text =
          ''
            // Audio settings
            volume "0.64";
            sensitivity "0.95";
            snd_musicvolume "0";
            snd_menumusic_volume "0";
            snd_roundstart_volume "0";
            snd_roundaction_volume "0";
            snd_roundend_volume "0";
            snd_mapobjective_volume "1";
            snd_tensecondwarning_volume "1";
            snd_mvp_volume "0.5";
            snd_deathcamera_volume "0.1";
            snd_mixahead "0.05";
            snd_headphone_pan_exponent "1.05";
            snd_rear_headphone_position "90";
            snd_front_headphone_position "45.0";
            voice_scale "0.45";

            // Crosshair settings
            cl_crosshairgap "-4";
            cl_crosshair_outlinethickness "1";
            cl_crosshaircolor_r "0";
            cl_crosshaircolor_g "255";
            cl_crosshaircolor_b "255";
            cl_crosshairalpha "255";
            cl_crosshair_dynamic_splitdist "3";
            cl_crosshair_recoil "true";
            cl_fixedcrosshairgap "3";
            cl_crosshaircolor "4";
            cl_crosshair_drawoutline "false";
            cl_crosshair_dynamic_splitalpha_innermod "0";
            cl_crosshair_dynamic_splitalpha_outermod "1";
            cl_crosshair_dynamic_maxdist_splitratio "1";
            cl_crosshairthickness "1";
            cl_crosshairdot "false";
            cl_crosshairgap_useweaponvalue "false";
            cl_crosshairusealpha "true";
            cl_crosshair_t "false";
            cl_crosshairstyle "4";
            cl_crosshairsize "1";

            // Viewmodel settings
            viewmodel_fov "68";
            viewmodel_offset_x "2.5";
            viewmodel_offset_y "2";
            viewmodel_offset_z "-2";
            viewmodel_presetpos "0";
            cl_viewmodel_shift_left_amt "0";
            cl_viewmodel_shift_right_amt "0";
            viewmodel_recoil "0";
            cl_bob_lower_amt "5";
            cl_bobamt_lat "0.1";
            cl_bobamt_vert "0.1";
            cl_righthand "1";

            // Radar/minimap settings
            cl_radar_always_centered "0";
            cl_radar_scale "0.4";
            cl_radar_icon_scale_min "0.6";
            cl_radar_rotate "1";
            cl_hud_radar_scale "1.15";
            cl_radar_square_with_scoreboard "1";

            // Movement binds with decal clearing
            bind "w" "+forward; r_cleardecals";
            bind "a" "+left; r_cleardecals";
            bind "s" "+back; r_cleardecals";
            bind "d" "+right; r_cleardecals";
            bind "ctrl" "+duck";
            bind "shift" "+sprint";

            // Bhop binds
            bind "mwheelup" "+jump";
            bind "mwheeldown" "+jump";
            bind "space" "+jump";

            // Voice and utility binds
            bind "mouse4" "+voicerecord";
            bind "mouse5" "slot7";
            bind "q" "slot8";
            bind "v" "slot6";
            bind "4" "slot10";
            bind "c" "switchhands";

            // Attack with decal clearing
            bind "mouse1" "+attack; r_cleardecals";

            // Net settings
            rate "786432";
            cl_interp "0";
            cl_interp_ratio "1";
            cl_updaterate "128";
            cl_cmdrate "128";

            // HUD & UI - Orange color
            hud_scaling "0.85";
            cl_showloadout "1";
            safezonex "1";
            safezoney "1";
            cl_hud_color "7";
            cl_hud_color_r "255";
            cl_hud_color_g "136";
            cl_hud_color_b "0";
            cl_draw_only_deathnotices "0";

            // Performance
            fps_max "0";
            fps_max_ui "120";
            engine_low_latency_sleep_after_client_tick "1";
            r_drawtracers_firstperson "1";

            // Buy binds
            bind "kp_ins" "buy vest;";
            bind "kp_end" "buy ak47; buy m4a1;";
            bind "kp_downarrow" "buy awp;";
            bind "kp_pgdn" "buy vest; buy vesthelm; buy defuser;";

            // Volume control
            bind "j" "incrementvar volume 0 1 0.1";
            bind "k" "incrementvar volume 0 1 -0.1";

            // Save config
            host_writeconfig;
          '';

        home.file.".local/share/Steam/steamapps/common/Counter-Strike Global Offensive/game/csgo/cfg/practice.cfg".text =
          ''
            sv_cheats 1;
            bot_kick;
            mp_warmup_end;
            mp_restartgame 1;
            mp_limitteams 0;
            mp_autoteambalance 0;
            mp_maxmoney 60000;
            mp_startmoney 60000;
            mp_buytime 9999;
            mp_buy_anywhere 1;
            mp_freezetime 0;
            mp_roundtime 60;
            mp_roundtime_defuse 60;
            mp_respawn_on_death_ct 1;
            mp_respawn_on_death_t 1;
            sv_infinite_ammo 2;
            ammo_grenade_limit_total 5;
            sv_grenade_trajectory 1;
            sv_grenade_trajectory_prac_pipreview 1;
            sv_grenade_trajectory_prac_trailtime 15;
            sv_grenade_trajectory_time 15;
            sv_grenade_trajectory_thickness 0.5;
            sv_showimpacts 1;
            sv_showimpacts_time 10;
            bind "capslock" "noclip";
            bind "n" "sv_rethrow_last_grenade";
          '';

        home.file.".local/share/Steam/steamapps/common/Counter-Strike Global Offensive/game/csgo/cfg/simulate.cfg".text =
          ''
            sv_cheats 0;
            mp_warmup_end;
            mp_restartgame 1;
            mp_limitteams 0;
            mp_autoteambalance 0;
            mp_maxmoney 16000;
            mp_startmoney 800;
            mp_buytime 50;
            mp_buy_anywhere 0;
            mp_freezetime 5;
            mp_roundtime 1.92;
            mp_roundtime_defuse 1.92;
            mp_respawn_on_death_ct 0;
            mp_respawn_on_death_t 0;
            sv_infinite_ammo 0;
            ammo_grenade_limit_total 4;
            sv_grenade_trajectory 0;
            sv_showimpacts 0;
            mp_friendlyfire 1;
            mp_damage_headshot_only 0;
            mp_free_armor 0;
            mp_solid_teammates 1;
            sv_talk_enemy_dead 0;
            sv_talk_enemy_living 0;
            sv_alltalk 0;
            mp_halftime 0;
            mp_match_can_clinch 0;
            mp_maxrounds 999;
            mp_overtime_enable 0;
            mp_overtime_maxrounds 6;
            mp_overtime_startmoney 10000;
          '';

        # home.file.".local/share/Steam/steamapps/common/Counter-Strike Global Offensive/game/csgo/cfg/gamestate_integration_score.cfg".text =
        #   ''
        #     "GSI"
        #     {
        #       "uri" "http://localhost:3000"
        #       "timeout" "5.0"
        #       "buffer" "0.1"
        #       "throttle" "0.5"
        #       "heartbeat" "30.0"
        #       "data"
        #       {
        #         "provider" "1"
        #         "map" "1"
        #         "round" "1"
        #         "player_id" "1"
        #         "player_state" "1"
        #         "player_weapons" "1"
        #       }
        #     }
        #   '';

        # systemd.user.services.cs2-gsi = lib.mkIf isLinux {
        #   Unit = {
        #     Description = "CS2 Game State Integration Server";
        #   };
        #   Install = {
        #     WantedBy = [ "default.target" ];
        #   };
        #   Service = {
        #     Type = "simple";
        #     ExecStart = "${pkgs.python3}/bin/python3 /home/${username}/.config/home/scripts/cs2-gsi-server.py";
        #     Restart = "always";
        #     RestartSec = "5s";
        #     PrivateTmp = false;
        #     Environment = "HOME=/home/${username}";
        #   };
        # };

        programs.steam.config = lib.mkIf isLinux {
          enable = true;
          closeSteam = true;
          users."459248649" = {
            id = 459248649;
            apps = {
              cs2-stretched = {
                id = 730;
                launchOptions = {
                  wrappers = [
                    (lib.getExe pkgs.gamemode)
                    (lib.getExe' pkgs.obs-studio-plugins.obs-vkcapture "obs-gamecapture")
                    # (lib.getExe pkgs.mangohud)
                    "${scriptDir}/cs2-wrapper.sh"
                  ];
                  args = [
                    "%command%"
                    "-novid"
                    "-nojoy"
                    "+fps_max"
                    "0"
                    "+mat_queue_mode"
                    "2"
                    "+cl_forcepreload"
                    "1"
                    "+fps_max_menu"
                    "60"
                    "-fullscreen"
                    "-h"
                    "960"
                    "-w"
                    "1280"
                    "+exec"
                    "autoexec.cfg"
                  ];
                };
              };
            };
          };
        };
      };
  };
}
