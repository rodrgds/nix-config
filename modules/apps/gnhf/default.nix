{
  lib,
  config,
  username,
  ...
}:
let
  cfg = config.apps.gnhf;
in
{
  options.apps.gnhf = {
    enable = lib.mkEnableOption "Enable gnhf autonomous agent orchestrator";
  };

  config = lib.mkIf cfg.enable {
    apps.javascript-toolchain = {
      enable = true;
      npm.cliPackages.gnhf.package = "gnhf@latest";
    };

    # gnhf drives OpenCode, which the javascript toolchain puts on the
    # session path. Its Pi-specific config lived in the removed Pi module.
    home-manager.users.${username}.home.file.".gnhf/config.yml".text = ''
      agent: opencode

      commitMessage:
        preset: conventional

      maxConsecutiveFailures: 3
      preventSleep: true
    '';
  };
}
