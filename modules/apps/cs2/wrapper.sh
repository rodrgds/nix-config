#!/usr/bin/env bash

SCRIPT_DIR="$HOME/.config/home/modules/scripts"

restore_desktop() {
  bash "${SCRIPT_DIR}/fullres.sh"
}

# Keep the gaming display active by itself while CS2 is running, then restore
# the normal layout after a clean exit, a crash, or Steam stopping the wrapper.
# SIGKILL is the only signal an EXIT trap cannot handle.
trap restore_desktop EXIT
if ! bash "${SCRIPT_DIR}/1monitor.sh"; then
  exit 1
fi

# CS2 otherwise selects X11 by default. Opt this launch into SDL3's native
# Wayland backend explicitly.
export SDL_VIDEO_DRIVER=wayland
"$@"
