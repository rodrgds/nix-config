#!/usr/bin/env bash
set -euo pipefail
script="$(cd "$(dirname "$0")/.." && pwd)/desktop-resources.sh"
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
settings_file="$fixture/settings-store.json"
desktop_memory_mib=4096
docker_settings_jq=$(command -v jq)
printf '%s\n' '{"MemoryMiB":10240,"AutoStart":false,"SwapMiB":4096}' > "$settings_file"
cp "$settings_file" "$fixture/original"

# A running VM keeps its settings unchanged, with no service interruption.
pgrep() { return 0; }
source "$script"
cmp "$settings_file" "$fixture/original"

# A stopped VM gets the memory limit without losing other preferences.
pgrep() { return 1; }
source "$script"
jq -e '.MemoryMiB == 4096 and .AutoStart == false and .SwapMiB == 4096' "$settings_file" >/dev/null
if [ "$(uname -s)" = Darwin ]; then
  mode=$(stat -f '%Lp' "$settings_file")
else
  mode=$(stat -c '%a' "$settings_file")
fi
[ "$mode" = 600 ]

# Malformed input never replaces the original settings or leaves a candidate.
printf '%s\n' '{broken' > "$settings_file"
cp "$settings_file" "$fixture/original"
if (source "$script"); then
  echo 'expected malformed settings to fail' >&2
  exit 1
fi
cmp "$settings_file" "$fixture/original"
[ "$(find "$fixture" -name '.settings-store.*' | wc -l | tr -d ' ')" = 0 ]
echo 'Docker resource settings tests passed'
