#!/usr/bin/env bash
set -euo pipefail
installer=$1
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
addons="$fixture/addons"
"$installer" install-addon --addons-dir "$addons"
addon="$addons/blender_mcp.py"
[ -s "$addon" ]
cp "$addon" "$fixture/expected.py"
# Existing installations can inherit the Nix store's read-only permissions.
chmod 444 "$addon"
"$installer" install-addon --addons-dir "$addons"
cmp "$addon" "$fixture/expected.py"
[ -w "$addon" ]
"$installer" install-addon --addons-dir "$addons"
cmp "$addon" "$fixture/expected.py"
echo 'Blender add-on repeat-install regression passed'
