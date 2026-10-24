#!/usr/bin/env bash

# Native Wayland stutters on rgo-desktop; use SDL's X11 backend via Xwayland.
export SDL_VIDEO_DRIVER=x11
exec "$@"
