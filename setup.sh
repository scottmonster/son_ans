#!/bin/bash
# Initial setup script for qyksys
# This script helps set up the vault password and initial secrets

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

PROJECT_NAME="qyksys"
LOCAL_VAULT_PASS_FILE="$HOME/.config/$PROJECT_NAME/vault_pass.txt"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running from project directory
if [[ ! -f "site.yml" ]] || [[ ! -d "roles" ]]; then
    log_error "This script must be run from the qyksys project root"
    exit 1
fi

log_info "Qyksys - Initial Setup"
echo

# Create vault password
setup_vault_password() {
    local vault_dir
    vault_dir="$(dirname "$LOCAL_VAULT_PASS_FILE")"
    
    mkdir -p "$vault_dir"
    
    if [[ -f "$LOCAL_VAULT_PASS_FILE" ]]; then
        log_info "Vault password file already exists at $LOCAL_VAULT_PASS_FILE"
        return
    fi
    
    log_info "Creating new vault password..."
    echo -n "Enter a secure vault password: "
    read -s vault_password
    echo
    
    echo -n "Confirm vault password: "
    read -s vault_password_confirm
    echo
    
    if [[ "$vault_password" != "$vault_password_confirm" ]]; then
        log_error "Passwords do not match"
        exit 1
    fi
    
    echo -n "$vault_password" > "$LOCAL_VAULT_PASS_FILE"
    chmod 600 "$LOCAL_VAULT_PASS_FILE"
    
    log_success "Vault password file created at $LOCAL_VAULT_PASS_FILE"
}

# Setup SSH keys
setup_ssh_keys() {
    log_info "Setting up SSH keys..."
    
    local ssh_key_path="$HOME/.ssh/id_ed25519"
    
    if [[ ! -f "$ssh_key_path" ]]; then
        log_info "No existing SSH key found. Generating new ed25519 key..."
        ssh-keygen -t ed25519 -f "$ssh_key_path" -N "" -C "$(whoami)@$(hostname)"
        log_success "New SSH key generated at $ssh_key_path"
    else
        log_info "Using existing SSH key at $ssh_key_path"
    fi
    
    # Update vault with SSH private key
    log_info "Adding SSH private key to vault..."
    
    # Create temporary vault file with new content
    cat > /tmp/vault_update.yml << EOF
---
ssh_private_key: |
$(sed 's/^/  /' "$ssh_key_path")
EOF
    
    # Encrypt the vault file (backup existing if it exists)
    if [[ -f "group_vars/all/vault.yml" ]]; then
        cp group_vars/all/vault.yml group_vars/all/vault.yml.backup
    fi
    ansible-vault encrypt /tmp/vault_update.yml --vault-password-file "$LOCAL_VAULT_PASS_FILE"
    mv /tmp/vault_update.yml group_vars/all/vault.yml
    
    # Update the public key file
    log_info "Adding SSH public key to encrypted storage..."
    cp "${ssh_key_path}.pub" vault/ssh_public_key.txt
    ansible-vault encrypt vault/ssh_public_key.txt --vault-password-file "$LOCAL_VAULT_PASS_FILE"
    mv vault/ssh_public_key.txt vault/ssh_public_key.txt.vault
    
    log_success "SSH keys added to vault"
}

# Create encrypted vault password file for repo
create_repo_vault_file() {
    log_info "Creating encrypted vault password file for repository..."
    
    cp "$LOCAL_VAULT_PASS_FILE" vault/vault_pass.txt
    ansible-vault encrypt vault/vault_pass.txt --vault-password-file "$LOCAL_VAULT_PASS_FILE"
    mv vault/vault_pass.txt vault/vault_pass.txt.vault
    
    log_success "Encrypted vault password file created"
}

# Main setup
main() {
    log_info "Starting initial setup for qyksys..."
    
    # Check for required tools
    for tool in ansible-vault ssh-keygen; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            log_error "Required tool '$tool' not found. Please install Ansible first."
            exit 1
        fi
    done
    
    setup_vault_password
    setup_ssh_keys
    create_repo_vault_file
    
    echo
    log_success "Initial setup completed!"
    log_info "Next steps:"
    echo "  1. Review the configuration in group_vars/all/main.yml"
    echo "  2. Run './bootstrap.sh' to provision this machine"
    echo "  3. Or run 'make personal' or 'make server' directly"
    echo
    log_info "To edit secrets later: make vault-edit"
    log_info "To view current secrets: make vault-view"
}

main "$@"