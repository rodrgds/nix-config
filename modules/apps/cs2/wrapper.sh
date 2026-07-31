#!/usr/bin/env bash

SCRIPT_DIR="$HOME/.config/home/modules/scripts"

restore_desktop() {
  bash "${SCRIPT_DIR}/fullres.sh"
}

# Restore the normal two-monitor layout after a clean exit, a game crash, or
# Steam terminating the wrapper. SIGKILL is the only signal an EXIT trap
# cannot handle.
trap restore_desktop EXIT

bash "${SCRIPT_DIR}/stretched.sh"

"$@"
