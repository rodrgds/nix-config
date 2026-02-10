# Centralized scripts module with auto-imports and shell aliases
{
  lib,
  config,
  pkgs,
  username,
  system,
  constants,
  ...
}:
let
  cfg = config.scripts;
  inherit (constants) isDarwin isLinux homeDir;

  # Read all script files from the scripts directory
  scriptDir = ./.;

  # Get all files in the scripts directory (excluding default.nix)
  scriptFiles = lib.filterAttrs (
    name: type: type == "regular" && name != "default.nix" && name != "__pycache__"
  ) (builtins.readDir scriptDir);

  # Generate script content from files
  scripts = lib.mapAttrs (name: _: builtins.readFile (scriptDir + "/${name}")) scriptFiles;

  # Generate shell aliases from script names (remove extensions for alias names)
  getAliasName =
    name:
    let
      # Remove .sh, .py extensions for cleaner aliases
      withoutSh = lib.removeSuffix ".sh" name;
      withoutPy = lib.removeSuffix ".py" withoutSh;
    in
    withoutPy;

  # Check if file is a shell script that needs bash prefix for Fish compatibility
  isShellScript = name: lib.hasSuffix ".sh" name;

  scriptAliases = lib.mapAttrs' (
    name: content:
    let
      aliasName = getAliasName name;
      # Point to source location in repo so aliases work immediately
      # (home-manager also installs to ~/.config/home/scripts/ for PATH access)
      scriptPath = "${homeDir}/.config/home/modules/scripts/${name}";
      # Prefix with 'bash ' for .sh scripts to ensure Fish compatibility
      aliasValue = if isShellScript name then "bash ${scriptPath}" else scriptPath;
    in
    lib.nameValuePair aliasName aliasValue
  ) scripts;

  # Common aliases for both platforms
  commonAliases = scriptAliases // {
    "h" = "cd ${homeDir}/.config/home";
    "v" = "nvim";
    "glog" = "git log --oneline --graph --decorate --all";
    "ll" = "ls -laFh";
    "rebuild" = "bash ${homeDir}/.config/home/modules/scripts/rebuild.sh";
    "rebuild-vps" = "${homeDir}/.config/home/modules/scripts/rebuild-vps.sh";

    # Legacy aliases (default to main secrets.yaml)
    "encrypt_secrets" = "bash ${homeDir}/.config/home/modules/scripts/secrets.sh encrypt secrets";
    "decrypt_secrets" = "bash ${homeDir}/.config/home/modules/scripts/secrets.sh decrypt secrets";
    "decrypt_to_file" =
      "bash ${homeDir}/.config/home/modules/scripts/secrets.sh decrypt-to-file secrets";
    "edit_secrets" = "bash ${homeDir}/.config/home/modules/scripts/secrets.sh edit secrets";

    # New flexible aliases - usage: decrypt secrets | decrypt vps-secrets
    "decrypt" = "bash ${homeDir}/.config/home/modules/scripts/secrets.sh decrypt";
    "encrypt" = "bash ${homeDir}/.config/home/modules/scripts/secrets.sh encrypt";
    "decrypt-file" = "bash ${homeDir}/.config/home/modules/scripts/secrets.sh decrypt-to-file";
    "edit-encrypted" = "bash ${homeDir}/.config/home/modules/scripts/secrets.sh edit";
  };

  # Linux-specific aliases
  linuxAliases = commonAliases // {
    "copy" = "xclip -selection clipboard";
    "rescrobbled-logs" = "journalctl --user -u rescrobbled.service -f";
  };
in
{
  options.scripts = {
    enable = lib.mkEnableOption "Enable centralized scripts with auto-imports";
  };

  config = lib.mkIf cfg.enable (
    # Use optionalAttrs to only include Linux-specific options on Linux
    lib.optionalAttrs isLinux {
      environment.sessionVariables = {
        PATH = lib.mkForce "${homeDir}/.config/home/scripts:$PATH";
      };
      environment.shellAliases = linuxAliases;
    }
    # Merge with Darwin-specific configuration
    // lib.optionalAttrs isDarwin {
      home-manager.users.${username} = {
        home.file = lib.mapAttrs' (
          name: content:
          lib.nameValuePair "scripts/${name}" {
            text = content;
            executable = true;
          }
        ) scripts;

        # Set up shell aliases via home-manager (generic, works with all shells)
        home.shellAliases = commonAliases;

        # Add scripts to PATH
        home.sessionPath = [ "${homeDir}/.config/home/scripts" ];
      };
    }
    # Merge with Linux-specific home-manager configuration
    // lib.optionalAttrs isLinux {
      home-manager.users.${username} = {
        home.file = lib.mapAttrs' (
          name: content:
          lib.nameValuePair "scripts/${name}" {
            text = content;
            executable = true;
          }
        ) scripts;
      };
    }
  );
}
