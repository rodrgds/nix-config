# Centralized scripts module with auto-imports and shell aliases
{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  cfg = config.scripts;

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
      scriptPath = "/home/${username}/.config/home/modules/scripts/${name}";
      # Prefix with 'bash ' for .sh scripts to ensure Fish compatibility
      aliasValue = if isShellScript name then "bash ${scriptPath}" else scriptPath;
    in
    lib.nameValuePair aliasName aliasValue
  ) scripts;
in
{
  options.scripts = {
    enable = lib.mkEnableOption "Enable centralized scripts with auto-imports";
  };

  config = lib.mkIf cfg.enable {
    # Add scripts directory to PATH
    environment.sessionVariables = {
      PATH = lib.mkForce "/home/${username}/.config/home/scripts:$PATH";
    };

    # Create shell aliases for all scripts + manual aliases
    # For .sh scripts, use 'bash scriptname' to ensure compatibility with Fish
    environment.shellAliases = scriptAliases // {
      "copy" = "xclip -selection clipboard";
      "v" = "nvim";
      "glog" = "git log --oneline --graph --decorate --all";
      "ll" = "ls -laFh";
      "rebuild" = "bash /home/${username}/.config/home/modules/scripts/rebuild.sh";
      "encrypt-secrets" =
        "bash -c 'cd /home/${username}/.config/home/secrets && nix-shell -p sops --run \"sops --encrypt secrets_plain.yaml\" > secrets.yaml && rm -f secrets_plain.yaml'";
      "decrypt-secrets" =
        "bash -c 'cd /home/${username}/.config/home/secrets && nix-shell -p sops --run \"sops --decrypt secrets.yaml\"'";
      "decrypt-to-file" =
        "bash -c 'cd /home/${username}/.config/home/secrets && nix-shell -p sops --run \"sops --decrypt secrets.yaml\" > secrets_plain.yaml && echo \"Decrypted to secrets_plain.yaml - edit and run encrypt-secrets when done\"'";
      "edit-secrets" =
        "bash -c 'cd /home/${username}/.config/home/secrets && nix-shell -p sops --run \"sops secrets.yaml\"'";
      "rescrobbled-logs" = "journalctl --user -u rescrobbled.service -f";
    };

    # Install scripts to the scripts directory
    home-manager.users.${username} =
      { ... }:
      {
        home.file = lib.mapAttrs' (
          name: content:
          lib.nameValuePair "scripts/${name}" {
            text = content;
            executable = true;
          }
        ) scripts;
      };
  };
}
