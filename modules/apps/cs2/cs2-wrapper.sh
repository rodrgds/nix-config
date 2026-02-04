#!/usr/bin/env bash

SCRIPT_DIR="$HOME/.config/home/scripts"

bash "${SCRIPT_DIR}/stretched.sh"

"$@"

bash "${SCRIPT_DIR}/fullres.sh"
