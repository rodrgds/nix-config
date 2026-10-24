claude_home=$1
shared_skills=$2
managed_config=$3
config_file="$claude_home/.claude.json"

mkdir -p "$claude_home/.claude/skills"

# Account state and user-defined servers share this file with MCP wiring.
temporary_config=$(mktemp "$config_file.XXXXXX")
trap 'rm -f "$temporary_config"' EXIT
if [ -f "$config_file" ]; then
  jq --slurpfile managed "$managed_config" \
    '.mcpServers = ((.mcpServers // {}) + $managed[0].mcpServers)' \
    "$config_file" > "$temporary_config"
else
  jq . "$managed_config" > "$temporary_config"
fi
if ! cmp -s "$config_file" "$temporary_config"; then
  chmod 600 "$temporary_config"
  mv "$temporary_config" "$config_file"
fi

for skill in "$shared_skills"/*; do
  [ -f "$skill/SKILL.md" ] || continue
  target="$claude_home/.claude/skills/$(basename "$skill")"
  if [ -e "$target" ] && [ ! -L "$target" ]; then
    printf 'claude-code: preserving existing skill %s\n' "$target" >&2
    continue
  fi
  ln -sfn "$skill" "$target"
done
