{
  lib,
  config,
  pkgs,
  constants,
  username,
  ...
}:
let
  cfg = config.apps.blender;
  inherit (constants) isDarwin isLinux;
  blenderMcp = pkgs.python3Packages.buildPythonApplication {
    pname = "mcp-for-blender";
    version = "2.1.0";
    format = "wheel";
    src = pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/cb/55/81ca1bafbc4f07ca89cdd41d04369bd3cbd6eaa1c038319db43675f1c292/mcp_for_blender-2.1.0-py3-none-any.whl";
      sha256 = "cbf8f60a9656325ff1f937751e695a837b8a7bad14cc55d266468419de930ed5";
    };
    dependencies = with pkgs.python3Packages; [
      mcp
      httpx
    ];
    # copy2 preserves the Nix store's read-only mode, breaking the next rebuild.
    postInstall = ''
      substituteInPlace "$out/${pkgs.python3.sitePackages}/blender_mcp/addon_manager.py" \
        --replace-fail 'import sys' $'import sys\nimport tempfile' \
        --replace-fail 'shutil.copy2(source, path)' '_install_addon_file(source, path)' \
        --replace-fail 'shutil.copy2(source, target)' '_install_addon_file(source, target)' \
        --replace-fail 'def install_addon(' 'def _install_addon_file(source: Path, target: Path) -> None:
          with tempfile.NamedTemporaryFile(dir=target.parent, delete=False) as handle:
              temporary = Path(handle.name)
          try:
              shutil.copyfile(source, temporary)
              temporary.chmod(0o644)
              os.replace(temporary, target)
          finally:
              temporary.unlink(missing_ok=True)


      def install_addon('
    '';
    pythonImportsCheck = [ "blender_mcp.server" ];
    makeWrapperArgs = [ "--set DISABLE_TELEMETRY 1" ];
    meta.mainProgram = "mcp-for-blender";
  };
  configPython = pkgs.python3.withPackages (ps: [ ps.tomlkit ]);
  configureCodex = pkgs.writeText "configure-blender-mcp.py" ''
    import os
    from pathlib import Path
    import tomlkit

    path = Path.home() / ".codex" / "config.toml"
    path.parent.mkdir(parents=True, exist_ok=True)
    original = path.read_text() if path.exists() else ""
    config = tomlkit.parse(original)
    servers = config.setdefault("mcp_servers", tomlkit.table())
    blender = servers.setdefault("blender", tomlkit.table())
    blender.update({
        "command": "${lib.getExe blenderMcp}",
        "args": ["--host", "127.0.0.1", "--port", "9876"],
        "startup_timeout_sec": 60,
        "tool_timeout_sec": 180,
    })
    blender.setdefault("env", tomlkit.table())["DISABLE_TELEMETRY"] = "1"
    updated = tomlkit.dumps(config)
    if updated != original:
        temporary = path.with_suffix(".toml.blender-tmp")
        temporary.write_text(updated)
        temporary.chmod(0o600)
        os.replace(temporary, path)
  '';
in
{
  options.apps.blender = {
    enable = lib.mkEnableOption "Enable Blender";
    mcp.enable = lib.mkEnableOption "Connect Blender to Codex through MCP";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.blender ];
      })
      (lib.optionalAttrs isDarwin {
        homebrew.casks = [ "blender" ];
      })
      (lib.mkIf cfg.mcp.enable {
        home-manager.users.${username} =
          { lib, ... }:
          {
            home.packages = [ blenderMcp ];
            # The bundled add-on and server must come from the same release.
            home.activation.blenderMcp = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
              ${lib.getExe blenderMcp} install-addon
              ${lib.optionalString config.apps.codex.enable ''
                ${configPython}/bin/python ${configureCodex}
              ''}
            '';
          };
      })
    ]
  );
}
