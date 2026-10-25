# Scoped security backport of the official nixpkgs 2.11.7 recipe, using the
# locked stable toolchain. Remove when the stable input carries this release.
# https://github.com/NixOS/nixpkgs/blob/3ec636362e1816bc2f0888fa0fa2c69f1bc9e504/pkgs/by-name/ca/caddy/package.nix
{
  lib,
  buildGoModule,
  fetchFromGitHub,
  installShellFiles,
  stdenv,
  writableTmpDirAsHomeHook,
  versionCheckHook,
}:
let
  version = "2.11.7";
  dist = fetchFromGitHub {
    owner = "caddyserver";
    repo = "dist";
    tag = "v${version}";
    hash = "sha256-KvdaqiX06I1ft+p67J1ISgP512SoZ4syDzfe888ZqGI=";
  };
in
buildGoModule {
  pname = "caddy";
  inherit version;

  src = fetchFromGitHub {
    owner = "caddyserver";
    repo = "caddy";
    tag = "v${version}";
    hash = "sha256-6+USPwF6LzDWUjrNRL2ncxSz5KmqJM0L/6o03Lh8YD8=";
  };
  vendorHash = "sha256-kJOl5h9gSfEK6ROT/MYOkBUr6MhiNBlbZVZPqwNpbBk=";

  ldflags = [
    "-s"
    "-X github.com/caddyserver/caddy/v2.CustomVersion=v${version}"
  ];
  tags = [
    "nobadger"
    "nomysql"
    "nopgx"
  ];

  nativeBuildInputs = [ installShellFiles ];
  nativeCheckInputs = [ writableTmpDirAsHomeHook ];
  __darwinAllowLocalNetworking = true;
  # Match the upstream nixpkgs recipe's sandbox-incompatible SNI test skip.
  checkFlags = [ "-skip=^TestReverseProxySNIPlaceHolder$" ];
  # Use the system CA store, which receives updates independently of Caddy.
  postConfigure = ''
    rm cmd/x509rootsfallback.go
  '';

  postInstall = ''
    install -Dm644 ${dist}/init/caddy.service ${dist}/init/caddy-api.service -t $out/lib/systemd/system
    substituteInPlace $out/lib/systemd/system/caddy.service $out/lib/systemd/system/caddy-api.service \
      --replace-fail "/usr/bin/caddy" "$out/bin/caddy"
  ''
  + lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
    $out/bin/caddy manpage --directory manpages
    installManPage manpages/*
    installShellCompletion --cmd caddy \
      --bash <($out/bin/caddy completion bash) \
      --fish <($out/bin/caddy completion fish) \
      --zsh <($out/bin/caddy completion zsh)
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    writableTmpDirAsHomeHook
    versionCheckHook
  ];
  versionCheckKeepEnvironment = [ "HOME" ];

  meta = {
    homepage = "https://caddyserver.com";
    description = "Fast and extensible HTTP web server with automatic HTTPS";
    changelog = "https://github.com/caddyserver/caddy/releases/tag/v${version}";
    license = lib.licenses.asl20;
    mainProgram = "caddy";
  };
}
