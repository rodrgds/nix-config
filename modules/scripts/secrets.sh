#!/usr/bin/env bash
# Secrets management script for multiple encrypted files
# Usage: secrets.sh <command> <secrets-name>
# Example: secrets.sh decrypt vps-secrets

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECRETS_DIR="${HOME}/.config/home/secrets"
AGE_KEY_FILE="${HOME}/.config/sops/age/keys.txt"

# Parse arguments
COMMAND="${1:-}"
SECRETS_NAME="${2:-secrets}"

# Convert secrets name to actual filename
if [[ "$SECRETS_NAME" == "secrets" ]]; then
    ENCRYPTED_FILE="${SECRETS_DIR}/secrets.yaml"
    PLAIN_FILE="${SECRETS_DIR}/secrets_plain.yaml"
elif [[ "$SECRETS_NAME" == "vps-secrets" ]] || [[ "$SECRETS_NAME" == "vps" ]]; then
    ENCRYPTED_FILE="${SECRETS_DIR}/vps-secrets.yaml"
    PLAIN_FILE="${SECRETS_DIR}/vps-secrets_plain.yaml"
else
    ENCRYPTED_FILE="${SECRETS_DIR}/${SECRETS_NAME}.yaml"
    PLAIN_FILE="${SECRETS_DIR}/${SECRETS_NAME}_plain.yaml"
fi

# Check if file exists
if [[ ! -f "$ENCRYPTED_FILE" ]]; then
    echo "❌ Error: Encrypted file not found: $ENCRYPTED_FILE"
    echo "Available secrets:"
    ls -1 "${SECRETS_DIR}"/*.yaml 2>/dev/null | xargs -n1 basename | sed 's/^/  - /' || echo "  (none found)"
    exit 1
fi

# Export age key for sops
export SOPS_AGE_KEY_FILE="$AGE_KEY_FILE"

cd "$SECRETS_DIR"

case "$COMMAND" in
    decrypt|d)
        echo "🔓 Decrypting $(basename "$ENCRYPTED_FILE")..."
        nix-shell -p sops --run "sops --decrypt '$ENCRYPTED_FILE'"
        ;;
    
    decrypt-to-file|dtf|decrypt-file)
        echo "🔓 Decrypting $(basename "$ENCRYPTED_FILE") to $(basename "$PLAIN_FILE")..."
        nix-shell -p sops --run "sops --decrypt '$ENCRYPTED_FILE'" > "$PLAIN_FILE"
        echo "✅ Decrypted to: $PLAIN_FILE"
        echo "📝 Edit the file, then run: encrypt $SECRETS_NAME"
        ;;
    
    encrypt|e)
        if [[ ! -f "$PLAIN_FILE" ]]; then
            echo "❌ Error: Plain file not found: $PLAIN_FILE"
            echo "Create it first or run: decrypt-to-file $SECRETS_NAME"
            exit 1
        fi
        
        echo "🔐 Encrypting $(basename "$PLAIN_FILE") to $(basename "$ENCRYPTED_FILE")..."
        nix-shell -p sops --run "sops --encrypt '$PLAIN_FILE'" > "$ENCRYPTED_FILE"
        rm -f "$PLAIN_FILE"
        echo "✅ Encrypted and removed plain file"
        ;;
    
    edit|ed)
        echo "✏️  Editing $(basename "$ENCRYPTED_FILE") with sops..."
        nix-shell -p sops --run "sops '$ENCRYPTED_FILE'"
        ;;
    
    *)
        echo "Usage: secrets.sh <command> [secrets-name]"
        echo ""
        echo "Commands:"
        echo "  decrypt, d          - Decrypt and output to stdout"
        echo "  decrypt-to-file, dtf - Decrypt to secrets_name_plain.yaml"
        echo "  encrypt, e          - Encrypt secrets_name_plain.yaml"
        echo "  edit, ed            - Edit directly with sops"
        echo ""
        echo "Secrets names:"
        echo "  secrets             - Main secrets (default)"
        echo "  vps-secrets, vps    - VPS-specific secrets"
        echo ""
        echo "Examples:"
        echo "  secrets.sh decrypt vps-secrets        # Decrypt VPS secrets to stdout"
        echo "  secrets.sh decrypt-to-file secrets    # Decrypt to secrets_plain.yaml"
        echo "  secrets.sh edit vps-secrets           # Edit VPS secrets with sops"
        echo "  decrypt vps-secrets                   # Using alias"
        echo "  encrypt secrets                       # Using alias"
        exit 1
        ;;
esac
