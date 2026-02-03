#!/usr/bin/env bash

# NixOS and nix-darwin rebuild script
# Usage: rebuild [--desktop|--laptop] [-a]
#   --desktop  Rebuild NixOS desktop configuration (rgo-desktop)
#   --laptop   Rebuild Darwin laptop configuration (rgo-laptop)
#   -a         Auto-commit changes after successful rebuild

set -e

# Default: detect system type
REBUILD_TARGET=""
AUTO_COMMIT=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --desktop)
            REBUILD_TARGET="desktop"
            shift
            ;;
        --laptop)
            REBUILD_TARGET="laptop"
            shift
            ;;
        -a)
            AUTO_COMMIT=true
            shift
            ;;
        -h|--help)
            echo "Usage: rebuild [--desktop|--laptop] [-a]"
            echo ""
            echo "Options:"
            echo "  --desktop  Rebuild NixOS desktop configuration (rgo-desktop)"
            echo "  --laptop   Rebuild Darwin/macOS laptop configuration (rgo-laptop)"
            echo "  -a         Auto-commit changes after successful rebuild"
            echo "  -h, --help Show this help message"
            echo ""
            echo "Examples:"
            echo "  rebuild --desktop          # Rebuild desktop NixOS config"
            echo "  rebuild --laptop           # Rebuild laptop Darwin config"
            echo "  rebuild --desktop -a       # Rebuild desktop and auto-commit"
            echo "  rebuild --laptop -a        # Rebuild laptop and auto-commit"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: rebuild [--desktop|--laptop] [-a]"
            exit 1
            ;;
    esac
done

# Auto-detect if no target specified
if [ -z "$REBUILD_TARGET" ]; then
    if [ "$(uname -s)" = "Darwin" ]; then
        REBUILD_TARGET="laptop"
        echo "Detected macOS - using laptop configuration (rgo-laptop)"
    elif [ -f /etc/NIXOS ]; then
        REBUILD_TARGET="desktop"
        echo "Detected NixOS - using desktop configuration (rgo-desktop)"
    else
        echo "Error: Could not detect system type. Please specify --desktop or --laptop"
        exit 1
    fi
fi

cd ~/.config/home

# Show git diff
echo "=== Git Diff ==="
git diff -U0 || true
echo ""

# Format Nix files
echo "=== Formatting Nix Files ==="
find . -name "*.nix" -type f -exec nixfmt {} \; 2>/dev/null || echo "nixfmt not available, skipping formatting"

# Rebuild based on target
if [ "$REBUILD_TARGET" = "desktop" ]; then
    echo "=== Rebuilding NixOS Desktop (rgo-desktop) ==="
    if sudo nixos-rebuild switch --flake .#rgo-desktop --impure; then
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
        notify-send "Error while rebuilding NixOS" 2>/dev/null || true
        exit 1
    fi
elif [ "$REBUILD_TARGET" = "laptop" ]; then
    echo "=== Rebuilding Darwin Laptop (rgo-laptop) ==="
    
    # Check if darwin-rebuild is available
    if ! command -v darwin-rebuild &> /dev/null; then
        echo "darwin-rebuild not found. Installing..."
        if ! nix run nix-darwin/master#darwin-rebuild -- switch --flake .#rgo-laptop; then
            echo "✗ Initial build failed!"
            exit 1
        fi
        echo "✓ Initial build successful! darwin-rebuild is now available."
        echo "Future rebuilds can use: darwin-rebuild switch --flake .#rgo-laptop"
    else
        if sudo darwin-rebuild switch --flake .#rgo-laptop --impure; then
            echo "✓ Rebuild successful!"
            
            # Commit if auto-commit flag is set and there are changes
            if [ "$AUTO_COMMIT" = true ] && [ -n "$(git status --porcelain)" ]; then
                git add -A
                git commit -m "Update rgo-laptop configuration"
                echo "✓ Changes committed"
            elif [ "$AUTO_COMMIT" = false ] && [ -n "$(git status --porcelain)" ]; then
                echo "⚠ Changes not committed (use -a flag to auto-commit)"
            fi
        else
            echo "✗ Rebuild failed!"
            osascript -e 'display notification "Error while rebuilding nix-darwin" with title "Rebuild Failed"' 2>/dev/null || true
            exit 1
        fi
    fi
fi
