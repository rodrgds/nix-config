#!/usr/bin/env bash

TEMP_IMAGE=$(mktemp --suffix=.png)
trap 'rm -f "$TEMP_IMAGE"' EXIT

CONTENT=$(xclip -o -selection clipboard)
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

freeze "${OPTS[@]}" <<< "$CONTENT" 2
if [[ $? -ne 0 ]]; then
    LANG=$(zenity --entry --title="Language?" --text="e.g., python, javascript:")
    [[ -z "$LANG" ]] && notify-send "Freeze" "Language not specified." && exit 1
    freeze "${OPTS[@]}" --language "$LANG" <<< "$CONTENT" || {
        zenity --error --text="Freeze failed"
        exit 1
    }
fi

[[ -s "$TEMP_IMAGE" ]] && xclip -selection clipboard -t image/png -i "$TEMP_IMAGE"
