#!/usr/bin/env bash

TEMP_IMAGE=$(mktemp --suffix=.png)
trap 'rm -f "$TEMP_IMAGE"' EXIT

CONTENT=$(wl-paste --no-newline 2>/dev/null || true)
[[ -z "$CONTENT" ]] && notify-send "Freeze" "Clipboard empty." && exit 1

OPTS=(
    --output "$TEMP_IMAGE"
    --font.family "JetBrains Mono"
    --font.size "14"
    --background "#100F0F"
    --padding "25,30"
    --margin "10"
    --border.radius "10"
    --border.width "1"
    --border.color "#666666"
    --font.ligatures
    --window
)

if ! freeze "${OPTS[@]}" <<< "$CONTENT" 2; then
    language=$(zenity --entry --title="Language?" --text="e.g., python, javascript:")
    [[ -z "$language" ]] && notify-send "Freeze" "Language not specified." && exit 1
    freeze "${OPTS[@]}" --language "$language" <<< "$CONTENT" || {
        zenity --error --text="Freeze failed"
        exit 1
    }
fi

if [[ -s "$TEMP_IMAGE" ]]; then
    wl-copy --type image/png < "$TEMP_IMAGE"
fi
