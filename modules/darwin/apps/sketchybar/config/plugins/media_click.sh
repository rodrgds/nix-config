#!/usr/bin/env bash

case "${BUTTON:-left}" in
  right)
    nowplaying-cli togglePlayPause
    ;;
  other)
    nowplaying-cli next
    ;;
  *)
    aerospace workspace 10
    ;;
esac
