#!/usr/bin/env bash

SCRIPT_DIR="$HOME/scripts"

bash "${SCRIPT_DIR}/stretched.sh"

"$@"

bash "${SCRIPT_DIR}/fullres.sh"
