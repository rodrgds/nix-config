#!/usr/bin/env bash

SCRIPT_DIR="$HOME/.config/home/modules/scripts"

bash "${SCRIPT_DIR}/stretched.sh"

"$@"

bash "${SCRIPT_DIR}/fullres.sh"
