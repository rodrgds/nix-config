#!/usr/bin/env bash

# NixOS rebuild script
# Usage: rebuild [-a]  (-a flag auto-commits changes)

set -e

# Parse arguments
AUTO_COMMIT=false
while getopts "a" opt; do
    case $opt in
        a)
            AUTO_COMMIT=true
            ;;
        \?)
            echo "Usage: rebuild [-a]"
            echo "  -a    Auto-commit changes after successful rebuild"
            exit 1
            ;;
    esac
done

cd ~/.config/home

# Show git diff
echo "=== Git Diff ==="
git diff -U0 || true
echo ""

# Format Nix files
echo "=== Formatting Nix Files ==="
find . -name "*.nix" -type f -exec nixfmt {} \; 2>/dev/null || echo "nixfmt not available, skipping formatting"

# Rebuild NixOS
echo "=== Rebuilding NixOS ==="
if sudo nixos-rebuild switch --flake .#rgopc --impure; then
    gen=$(nixos-rebuild list-generations | awk '$NF == "True" { print $1 }')
    echo "✓ Rebuild successful! Generation: $gen"
    
    # Commit if auto-commit flag is set and there are changes
    if [ "$AUTO_COMMIT" = true ] && [ -n "$(git status --porcelain)" ]; then
        git add -A
        git commit -m "Generation $gen"
        echo "✓ Changes committed"
    elif [ "$AUTO_COMMIT" = false ] && [ -n "$(git status --porcelain)" ]; then
        echo "⚠ Changes not committed (use -a flag to auto-commit)"
    fi
else
    echo "✗ Rebuild failed!"
    notify-send "Error while rebuilding NixOS"
    exit 1
fi
