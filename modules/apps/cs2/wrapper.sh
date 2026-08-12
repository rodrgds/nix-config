#!/usr/bin/env bash

# CS2 otherwise selects X11 by default. Opt this launch into SDL3's native
# Wayland backend explicitly.
export SDL_VIDEO_DRIVER=wayland
exec "$@"
