#!/usr/bin/env bash
set -e

parse_flake_inputs() {
    awk '
        /^\s*inputs\s*=\s*\{/ {
            in_inputs = 1
            depth = 1
            next
        }

        in_inputs {
            opens = gsub(/\{/, "{")
            closes = gsub(/\}/, "}")

            if (depth == 1 && $0 ~ /^[[:space:]]*[[:alnum:]_.-]+[[:space:]]*=/) {
                name = $0
                sub(/^[[:space:]]*/, "", name)
                sub(/[[:space:]]*=.*/, "", name)
                sub(/\.url$/, "", name)
                print name
            }

            depth += opens - closes
            if (depth == 0) {
                exit
            }
        }
    ' flake.nix
}

select_flake_inputs() {
    local -a inputs=("$@")
    local -a defaults=()
    local -a selected=()
    local reply token idx

    for input in "${inputs[@]}"; do
        if [[ "$input" != "nixpkgs-davinci" ]]; then
            defaults+=("$input")
        fi
    done

    echo "=== Flake Inputs ==="
    for i in "${!inputs[@]}"; do
        printf "%2d. %s\n" "$((i + 1))" "${inputs[i]}"
    done
    echo ""
    echo "Update inputs before rebuilding?"
    echo "  Enter: skip"
    echo "  d: update default set (all except nixpkgs-davinci)"
    echo "  a: update all inputs"
    echo "  numbers: choose specific inputs, e.g. '1 3 5' or '1,3,5'"
    read -r -p "Selection: " reply

    case "${reply// /}" in
        "")
            return 0
            ;;
        d|D|default|DEFAULT)
            selected=("${defaults[@]}")
            ;;
        a|A|all|ALL)
            selected=("${inputs[@]}")
            ;;
        *)
            reply="${reply//,/ }"
            for token in $reply; do
                if [[ ! "$token" =~ ^[0-9]+$ ]]; then
                    echo "Invalid selection: $token" >&2
                    exit 1
                fi

                idx=$((token - 1))
                if (( idx < 0 || idx >= ${#inputs[@]} )); then
                    echo "Selection out of range: $token" >&2
                    exit 1
                fi

                selected+=("${inputs[idx]}")
            done
            ;;
    esac

    if ((${#selected[@]} == 0)); then
        return 0
    fi

    dedupe_array selected
    update_selected_inputs "${selected[@]}"
}

dedupe_array() {
    local array_name="$1"
    local -n array_ref="$array_name"
    local -A seen=()
    local -a deduped=()
    local item

    for item in "${array_ref[@]}"; do
        if [[ -z "${seen[$item]:-}" ]]; then
            deduped+=("$item")
            seen[$item]=1
        fi
    done

    array_ref=("${deduped[@]}")
}

update_selected_inputs() {
    local -a selected=("$@")
    local -a cmd=("nix" "flake" "update" "--flake" "path:.")
    local input

    echo ""
    echo "=== Updating Flake Inputs ==="
    printf "Selected:"
    for input in "${selected[@]}"; do
        printf " %s" "$input"
        cmd+=("$input")
    done
    printf "\n"

    "${cmd[@]}"
    echo ""
}

current_darwin_generation() {
    darwin-rebuild --list-generations 2>/dev/null | awk '
        $1 ~ /^[0-9]+$/ && /current/ {
            print $1
            exit
        }
    '
}

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

if [ "$TARGET" = "desktop" ]; then
    mapfile -t FLAKE_INPUTS < <(parse_flake_inputs)
    select_flake_inputs "${FLAKE_INPUTS[@]}"
else
    echo "=== Flake Inputs ==="
    echo "Skipping flake input update prompt on macOS"
    echo ""
fi

echo "=== Linting ==="
statix check . || true

echo "=== Formatting ==="
find . -name "*.nix" -exec nixfmt {} + 2>/dev/null || true

case "$TARGET" in
    desktop)
        echo "=== Rebuilding NixOS ==="
        nh os switch path:. -H rgo-desktop -- --impure || {
            notify-send "Error while rebuilding NixOS" 2>/dev/null || true
            exit 1
        }
        gen=$(nixos-rebuild list-generations | awk '$NF == "True" { print $1 }')
        msg="Generation $gen"
        ;;
    laptop)
        echo "=== Rebuilding Darwin ==="
        nh darwin switch path:. -H rgo-laptop -- --impure || {
            osascript -e 'display notification "Error while rebuilding nix-darwin" with title "Rebuild Failed"' 2>/dev/null || true
            exit 1
        }
        gen="$(current_darwin_generation)"
        if [ -n "$gen" ]; then
            msg="Generation $gen"
        else
            msg="Darwin rebuild $(date '+%Y-%m-%d %H:%M:%S')"
        fi
        ;;
esac

if [ -n "$(git status --porcelain)" ]; then
    echo ""
    echo "=== Changes to commit ==="
    git diff HEAD
    echo ""
    read -r -p "Commit these changes with message '$msg'? [y/N] " answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
        git add -A
        git commit -m "$msg"
        echo "✓ Committed: $msg"
    else
        echo "✗ Commit skipped"
    fi
fi

echo "✓ Rebuild successful!"
