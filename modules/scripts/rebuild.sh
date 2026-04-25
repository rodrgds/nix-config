#!/usr/bin/env bash
set -e

# Parse optional target override
TARGET=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --desktop) TARGET="desktop"; shift ;;
        --laptop)  TARGET="laptop";  shift ;;
        -h|--help)
            echo "Usage: rebuild [--desktop|--laptop]"
            exit 0 ;;
        *)
            echo "Unknown option: $1"
            exit 1 ;;
    esac
done

# Auto-detect if not specified
if [ -z "$TARGET" ]; then
    [ "$(uname -s)" = "Darwin" ] && TARGET="laptop"
    [ -f /etc/NIXOS ] && TARGET="desktop"
    [ -z "$TARGET" ] && { echo "Error: Unknown system. Use --desktop or --laptop."; exit 1; }
fi

cd ~/.config/home

echo "=== Linting ==="
statix check . || true

echo "=== Formatting ==="
find . -name "*.nix" -exec nixfmt {} + 2>/dev/null || true

case "$TARGET" in
    desktop)
        echo "=== Rebuilding NixOS ==="
        nh os switch . -H rgo-desktop -- --impure || {
            notify-send "Error while rebuilding NixOS" 2>/dev/null || true
            exit 1
        }
        gen=$(nixos-rebuild list-generations | awk '$NF == "True" { print $1 }')
        msg="Generation $gen"
        ;;
    laptop)
        echo "=== Rebuilding Darwin ==="
        nh darwin switch . -H rgo-laptop -- --impure || {
            osascript -e 'display notification "Error while rebuilding nix-darwin" with title "Rebuild Failed"' 2>/dev/null || true
            exit 1
        }
        msg="Update rgo-laptop configuration"
        ;;
esac

if [ -n "$(git status --porcelain)" ]; then
    git add -A
    git commit -m "$msg"
    echo "✓ Committed: $msg"
fi

echo "✓ Rebuild successful!"
