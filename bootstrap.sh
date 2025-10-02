#!/bin/bash
# Bootstrap script for machine provisioning with Ansible
# Usage: curl -sSL https://path-to-repo/bootstrap.sh | bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Project configuration
PROJECT_NAME="qyksys"
LOCAL_VAULT_PASS_FILE="$HOME/.config/$PROJECT_NAME/vault_pass.txt"
REPO_VAULT_PASS_FILE="vault/vault_pass.txt.vault"

# Logging functions
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

# Detect OS
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v apt-get >/dev/null 2>&1; then
            echo "debian"
        elif command -v yum >/dev/null 2>&1 || command -v dnf >/dev/null 2>&1; then
            echo "redhat"
        elif command -v pacman >/dev/null 2>&1; then
            echo "arch"
        else
            echo "linux"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
        echo "windows"
    else
        echo "unknown"
    fi
}

# Install prerequisites
install_prerequisites() {
    local os_type="$1"
    
    log_info "Installing prerequisites for $os_type..."
    
    case "$os_type" in
        "debian")
            sudo apt-get update
            sudo apt-get install -y python3 python3-pip python3-venv git
            ;;
        "redhat")
            if command -v dnf >/dev/null 2>&1; then
                sudo dnf install -y python3 python3-pip git
            else
                sudo yum install -y python3 python3-pip git
            fi
            ;;
        "arch")
            sudo pacman -S --noconfirm python python-pip git
            ;;
        "macos")
            # Assume Homebrew is available or install it
            if ! command -v brew >/dev/null 2>&1; then
                log_info "Installing Homebrew..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            fi
            brew install python git
            ;;
        "windows")
            log_error "Windows support requires manual Python and Git installation"
            exit 1
            ;;
        *)
            log_error "Unsupported OS: $os_type"
            exit 1
            ;;
    esac
}

# Install Ansible
install_ansible() {
    log_info "Installing Ansible..."
    
    if command -v pipx >/dev/null 2>&1; then
        pipx install ansible-core
    else
        # Install pipx first, then ansible
        python3 -m pip install --user pipx
        python3 -m pipx ensurepath
        export PATH="$HOME/.local/bin:$PATH"
        pipx install ansible-core
    fi
    
    # Verify installation
    if command -v ansible-playbook >/dev/null 2>&1; then
        log_success "Ansible installed successfully"
    else
        log_error "Failed to install Ansible"
        exit 1
    fi
}

# Setup vault password file
setup_vault_password() {
    local vault_dir
    vault_dir="$(dirname "$LOCAL_VAULT_PASS_FILE")"
    
    # Create config directory if it doesn't exist
    mkdir -p "$vault_dir"
    
    # Check if local vault password file exists
    if [[ ! -f "$LOCAL_VAULT_PASS_FILE" ]]; then
        log_info "Local vault password file not found at $LOCAL_VAULT_PASS_FILE"
        
        # Check if encrypted vault password exists in repo
        if [[ -f "$REPO_VAULT_PASS_FILE" ]]; then
            log_info "Found encrypted vault password in repo. Attempting to decrypt..."
            
            echo -n "Enter vault decryption password: "
            read -s master_password
            echo
            
            # Decrypt the vault password file
            if echo "$master_password" | ansible-vault decrypt --vault-password-file=- "$REPO_VAULT_PASS_FILE" --output="$LOCAL_VAULT_PASS_FILE" 2>/dev/null; then
                log_success "Vault password file decrypted and placed at $LOCAL_VAULT_PASS_FILE"
                chmod 600 "$LOCAL_VAULT_PASS_FILE"
            else
                log_error "Failed to decrypt vault password file"
                exit 1
            fi
        else
            log_info "No encrypted vault password found. Creating new vault password..."
            
            echo -n "Enter new vault password: "
            read -s vault_password
            echo
            
            echo -n "$vault_password" > "$LOCAL_VAULT_PASS_FILE"
            chmod 600 "$LOCAL_VAULT_PASS_FILE"
            
            log_success "New vault password file created at $LOCAL_VAULT_PASS_FILE"
        fi
    else
        log_info "Using existing vault password file at $LOCAL_VAULT_PASS_FILE"
    fi
}

# Select profile
select_profile() {
    echo
    log_info "Select a profile for this machine:"
    echo "1) personal - Sets up a personal workstation (sudo, ufw, zsh, ssh client)"
    echo "2) server - Sets up a server (sudo, ufw, zsh, ssh server)"
    echo
    
    while true; do
        echo -n "Enter your choice (1 or 2): "
        read -r choice
        
        case "$choice" in
            1|"personal")
                echo "personal"
                return
                ;;
            2|"server")
                echo "server"
                return
                ;;
            *)
                log_warning "Invalid choice. Please enter 1 or 2."
                ;;
        esac
    done
}

# Run Ansible playbook
run_ansible() {
    local profile="$1"
    
    log_info "Running Ansible playbook with profile: $profile"
    
    # Set environment variables for Ansible
    export ANSIBLE_VAULT_PASSWORD_FILE="$LOCAL_VAULT_PASS_FILE"
    export ANSIBLE_HOST_KEY_CHECKING=False
    
    # Run the playbook
    ansible-playbook \
        -i inventory/local \
        -e "profile=$profile" \
        --vault-password-file="$LOCAL_VAULT_PASS_FILE" \
        site.yml
}

# Main execution
main() {
    log_info "Starting machine provisioning bootstrap..."
    
    # Detect OS
    OS_TYPE=$(detect_os)
    log_info "Detected OS: $OS_TYPE"
    
    # Check if we're in the project directory
    if [[ ! -f "site.yml" ]] || [[ ! -d "roles" ]]; then
        log_error "This script must be run from the project root directory"
        log_error "Make sure you have cloned the repository and are in the correct directory"
        exit 1
    fi
    
    # Install prerequisites if needed
    if ! command -v python3 >/dev/null 2>&1 || ! command -v git >/dev/null 2>&1; then
        install_prerequisites "$OS_TYPE"
    fi
    
    # Install Ansible if not present
    if ! command -v ansible-playbook >/dev/null 2>&1; then
        install_ansible
    else
        log_info "Ansible already installed"
    fi
    
    # Setup vault password
    setup_vault_password
    
    # Select profile
    PROFILE=$(select_profile)
    
    # Run Ansible
    run_ansible "$PROFILE"
    
    log_success "Machine provisioning completed successfully!"
    log_info "Profile: $PROFILE"
    log_info "Vault password file: $LOCAL_VAULT_PASS_FILE"
}

# Run main function
main "$@"