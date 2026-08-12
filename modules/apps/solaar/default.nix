{
  lib,
  config,
  pkgs,
  username,
  constants,
  ...
}:
let
  cfg = config.apps.solaar;
  inherit (constants) isLinux;
in
{
  options.apps.solaar = {
    enable = lib.mkEnableOption "Enable Solaar";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.solaar ];
      })

      {
        home-manager.users.${username} = _: {
          systemd.user.services.solaar = lib.mkIf isLinux {
            Unit = {
              Description = "Solaar Logitech device manager";
              PartOf = [ "graphical-session.target" ];
            };
            Install = {
              WantedBy = [ "graphical-session.target" ];
            };
            Service = {
              ExecStart = "${pkgs.solaar}/bin/solaar --window=hide";
              # A second invocation asks the existing tray process to expose
              # its window and then exits. Restarting on every clean/explicit
              # exit therefore creates an endless reopen loop. Preserve crash
              # recovery without undoing an intentional close.
              Restart = "on-abnormal";
              RestartSec = "3s";
            };
          };

          home.file.".config/solaar/config.yaml".text = ''
            - 1.1.16
            - _NAME: PRO X Wireless
              _absent:
                [
                  led_control,
                  led_zone_,
                  hi-res-scroll,
                  lowres-scroll-mode,
                  hires-smooth-invert,
                  hires-smooth-resolution,
                  hires-scroll-mode,
                  scroll-ratchet,
                  smart-shift,
                  thumb-scroll-invert,
                  thumb-scroll-mode,
                  report_rate_extended,
                  pointer_speed,
                  dpi_extended,
                  speed-change,
                  backlight,
                  backlight_level,
                  backlight_duration_hands_out,
                  backlight_duration_hands_in,
                  backlight_duration_powered,
                  backlight-timed,
                  rgb_control,
                  rgb_zone_,
                  brightness_control,
                  per-key-lighting,
                  fn-swap,
                  reprogrammable-keys,
                  persistent-remappable-keys,
                  divert-keys,
                  disable-keyboard-keys,
                  crown-smooth,
                  divert-crown,
                  divert-gkeys,
                  m-key-leds,
                  mr-key-led,
                  multiplatform,
                  change-host,
                  gesture2-gestures,
                  gesture2-divert,
                  gesture2-params,
                  sidetone,
                  equalizer,
                  adc_power_management,
                ]
              _battery: 4100
              _modelId: 4093C0940000
              _sensitive:
                {
                  dpi: false,
                  hires-scroll-mode: ignore,
                  hires-smooth-invert: ignore,
                  hires-smooth-resolution: ignore,
                  onboard_profiles: false,
                  report_rate: false,
                }
              _serial: 9A2C2E57
              _unitId: 9A2C2E57
              _wpid: "4093"
              dpi: 550
              onboard_profiles: 0
              report_rate: 1
          '';

          home.file.".config/autostart/solaar.desktop".text = ''
            [Desktop Entry]
            Type=Application
            Name=Solaar
            Hidden=true
          '';
        };
      }
    ]
  );
}
