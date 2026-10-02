if [ -f "$settings_file" ]; then
  if pgrep -u "$(id -u)" -f '/Applications/Docker.app/Contents/MacOS/com.docker.backend' >/dev/null; then
    echo "Docker Desktop is running; stop it and rebuild to apply the $desktop_memory_mib MiB memory allowance."
  else
    settings_tmp=$(mktemp "$(dirname "$settings_file")/.settings-store.XXXXXX")
    if "$docker_settings_jq" --argjson memory "$desktop_memory_mib" '.MemoryMiB = $memory' "$settings_file" > "$settings_tmp"; then
      chmod 600 "$settings_tmp"
      mv "$settings_tmp" "$settings_file"
    else
      rm -f "$settings_tmp"
      exit 1
    fi
  fi
fi
