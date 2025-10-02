#!/bin/bash
# Script to change vault password securely

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration
VAULT_PASS_FILE="$HOME/.config/qyksys/vault_pass.txt"
OLD_VAULT_PASS_FILE="/tmp/old_vault_pass.txt"
NEW_VAULT_PASS_FILE="/tmp/new_vault_pass.txt"

log_info "Vault Password Change Tool"
echo

# Check if we're in the right directory
if [[ ! -f "group_vars/all/vault.yml" ]]; then
    log_error "Must be run from the project root directory"
    exit 1
fi

# Get current password
log_info "Current vault password file: $VAULT_PASS_FILE"
if [[ ! -f "$VAULT_PASS_FILE" ]]; then
    log_error "Vault password file not found!"
    exit 1
fi

# Copy current password to temp file
cp "$VAULT_PASS_FILE" "$OLD_VAULT_PASS_FILE"

# Get new password
echo -n "Enter new vault password: "
read -s new_password
echo

echo -n "Confirm new vault password: "
read -s confirm_password
echo

if [[ "$new_password" != "$confirm_password" ]]; then
    log_error "Passwords do not match!"
    rm -f "$OLD_VAULT_PASS_FILE"
    exit 1
fi

# Save new password to temp file
echo -n "$new_password" > "$NEW_VAULT_PASS_FILE"
chmod 600 "$NEW_VAULT_PASS_FILE"

log_info "Changing password for all encrypted files..."

# Files to rekey
FILES_TO_REKEY=(
    "group_vars/all/vault.yml"
    "vault/vault_pass.txt.vault"
    "vault/ssh_public_key.txt.vault"
)

# Rekey each file
for file in "${FILES_TO_REKEY[@]}"; do
    if [[ -f "$file" ]]; then
        log_info "Rekeying $file..."
        if ansible-vault rekey "$file" --vault-password-file "$OLD_VAULT_PASS_FILE" --new-vault-password-file "$NEW_VAULT_PASS_FILE"; then
            log_success "Successfully rekeyed $file"
        else
            log_error "Failed to rekey $file"
            rm -f "$OLD_VAULT_PASS_FILE" "$NEW_VAULT_PASS_FILE"
            exit 1
        fi
    else
        log_error "File not found: $file"
    fi
done

# Update the local vault password file
cp "$NEW_VAULT_PASS_FILE" "$VAULT_PASS_FILE"
chmod 600 "$VAULT_PASS_FILE"

# Clean up temp files
rm -f "$OLD_VAULT_PASS_FILE" "$NEW_VAULT_PASS_FILE"

log_success "Vault password successfully changed!"
log_info "New password saved to: $VAULT_PASS_FILE"

# Test the new password
log_info "Testing new password..."
if ansible-vault view group_vars/all/vault.yml --vault-password-file "$VAULT_PASS_FILE" >/dev/null 2>&1; then
    log_success "New password works correctly!"
else
    log_error "Something went wrong - new password doesn't work"
    exit 1
fi

echo
log_success "All done! Your vault password has been changed."
log_info "You can now run: make personal or make server"