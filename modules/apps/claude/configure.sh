claude_home=$1
shared_skills=$2
managed_config=$3
managed_settings=$4
config_file="$claude_home/.claude.json"
settings_file="$claude_home/.claude/settings.json"

mkdir -p "$claude_home/.claude/skills"

temporary_config=$(mktemp "$config_file.XXXXXX")
temporary_settings=$(mktemp "$settings_file.XXXXXX")
trap 'rm -f "$temporary_config" "$temporary_settings"' EXIT

install_config() {
  if ! cmp -s "$1" "$2"; then
    chmod 600 "$2"
    mv "$2" "$1"
  fi
}

# Account state and user-defined servers share this file with MCP wiring.
if [ -f "$config_file" ]; then
  jq --slurpfile managed "$managed_config" \
    '.mcpServers = ((.mcpServers // {}) + $managed[0].mcpServers)' \
    "$config_file" > "$temporary_config"
else
  jq . "$managed_config" > "$temporary_config"
fi
install_config "$config_file" "$temporary_config"

# Claude settings stay mutable, but managed values win.
if [ -f "$settings_file" ]; then
  jq --slurpfile managed "$managed_settings" \
    '.attribution = ((.attribution | if type == "object" then . else {} end) + $managed[0].attribution)' \
    "$settings_file" > "$temporary_settings"
else
  jq . "$managed_settings" > "$temporary_settings"
fi
install_config "$settings_file" "$temporary_settings"

for skill in "$shared_skills"/*; do
  [ -f "$skill/SKILL.md" ] || continue
  target="$claude_home/.claude/skills/$(basename "$skill")"
  if [ -e "$target" ] && [ ! -L "$target" ]; then
    printf 'claude-code: preserving existing skill %s\n' "$target" >&2
    continue
  fi
  ln -sfn "$skill" "$target"
done
