#!/bin/bash
# Bootstrap script for qyksys system provisioning
# Usage: curl -sSL https://raw.githubusercontent.com/scottmonster/son_ans/refs/heads/master/bootstrap.sh | bash


set -euo pipefail
VERSION="1"
DEBUG=true

if [[ -n "${DEBUG:-}" ]]; then
  echo "turning on debug"
  # Enable per-command timing (Bash 5.1+). Ignore if unsupported.
  if shopt -q xtrace-time 2>/dev/null; then
    shopt -s xtrace-time
  else
    set -o xtrace-time 2>/dev/null || true
  fi

  # Trace prefix: time file:line:function
  # export PS4='+ [${EPOCHREALTIME} ${BASH_SOURCE##*/}:${LINENO}:${FUNCNAME[0]}] '
  export PS4='+ [line:${LINENO}] '

  # Turn on xtrace
  set -x
fi

echo "Running qyksys bootstrap version $VERSION"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Project configuration
PROJECT_NAME="qyksys"
REPO_URL="https://github.com/scottmonster/son_ans.git"
LOCAL_VAULT_PASS_FILE="$HOME/.config/$PROJECT_NAME/vault_pass.txt"
REPO_VAULT_PASS_FILE="vault/vault_pass.txt.vault"
WORK_DIR="/tmp/qyksys-$$"

# Store original user info before any privilege escalation
ORIGINAL_USER="${SUDO_USER:-$USER}"
ORIGINAL_HOME="${SUDO_HOME:-$HOME}"

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

# Cleanup function
cleanup() {
    if [[ -d "$WORK_DIR" ]]; then
        rm -rf "$WORK_DIR"
    fi
}

# Set trap for cleanup
trap cleanup EXIT

# Check if user has sudo access or is root
check_privileges() {
    if [[ $EUID -eq 0 ]]; then
        log_info "Running as root"
        return 0
    elif groups "$USER" | grep -q '\bsudo\b\|\bwheel\b'; then
        # User is in sudo/wheel group, test sudo access
        if sudo -n true 2>/dev/null; then
            log_info "User has passwordless sudo access"
            return 0
        elif command -v sudo >/dev/null 2>&1; then
            log_info "User is in sudo group, testing sudo access..."
            if sudo true 2>/dev/null; then
                log_info "User has sudo access"
                return 0
            else
                log_error "Sudo authentication failed"
                return 1
            fi
        else
            log_warning "sudo command not available"
            return 1
        fi
    else
        log_info "User not in sudo/wheel group, will need root access for package installation"
        return 1
    fi
}

# Switch to root if needed, preserving original user context
ensure_root_for_packages() {
    local os_type="$1"
    
    if ! check_privileges; then
        log_info "User not in sudo group. Attempting to switch to root for package installation..."
        log_warning "You will be prompted for the root password"
        
        # Create a temporary script for root to execute
        local root_script="/tmp/qyksys_install_packages_$$"
        cat > "$root_script" << EOF
#!/bin/bash
set -euo pipefail

echo "[INFO] Installing packages as root..."

case "$os_type" in
    "debian")
        apt-get update
        apt-get install -y python3 python3-pip python3-venv git curl sudo
        ;;
    "redhat")
        if command -v dnf >/dev/null 2>&1; then
            dnf install -y python3 python3-pip git curl sudo
        else
            yum install -y python3 python3-pip git curl sudo
        fi
        ;;
    "arch")
        pacman -S --noconfirm python python-pip git curl sudo
        ;;
    *)
        echo "[ERROR] Unsupported OS for automatic package installation: $os_type"
        exit 1
        ;;
esac

# Add user to sudo group if not already there
if ! groups "$ORIGINAL_USER" | grep -q '\bsudo\b\|\bwheel\b'; then
    echo "[INFO] Adding $ORIGINAL_USER to sudo group..."
    
    # Ensure sudo group exists
    if ! getent group sudo >/dev/null 2>&1; then
        groupadd sudo
    fi
    
    usermod -a -G sudo "$ORIGINAL_USER"
    
    # For RedHat/Arch systems, also add to wheel group
    if [[ "$os_type" == "redhat" ]] || [[ "$os_type" == "arch" ]]; then
        if ! getent group wheel >/dev/null 2>&1; then
            groupadd wheel
        fi
        usermod -a -G wheel "$ORIGINAL_USER"
    fi
fi

echo "[SUCCESS] Package installation completed"
rm -f "$root_script"
EOF

        chmod +x "$root_script"
        
        # Execute the script as root
        if su -c "ORIGINAL_USER='$ORIGINAL_USER' '$root_script'" root; then
            log_success "Packages installed successfully"
            log_info "User $ORIGINAL_USER has been added to sudo group"
            log_warning "Note: You may need to log out and back in for sudo group membership to take effect"
            return 0
        else
            log_error "Failed to install packages as root"
            rm -f "$root_script"
            exit 1
        fi
    fi
    return 0
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
    
    # Check if we need to handle privilege escalation
    if ! check_privileges && [[ "$os_type" != "macos" ]]; then
        ensure_root_for_packages "$os_type"
    fi
    
    case "$os_type" in
        "debian")
            if check_privileges; then
                sudo apt-get update
                sudo apt-get install -y python3 python3-pip python3-venv git curl
            fi
            ;;
        "redhat")
            if check_privileges; then
                if command -v dnf >/dev/null 2>&1; then
                    sudo dnf install -y python3 python3-pip git curl
                else
                    sudo yum install -y python3 python3-pip git curl
                fi
            fi
            ;;
        "arch")
            if check_privileges; then
                sudo pacman -S --noconfirm python python-pip git curl
            fi
            ;;
        "macos")
            # Assume Homebrew is available or install it
            if ! command -v brew >/dev/null 2>&1; then
                log_info "Installing Homebrew..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            fi
            brew install python git curl
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
    
    # Ensure we're provisioning the original user, not root
    if [[ "$ORIGINAL_USER" != "$USER" ]]; then
        log_info "Ensuring provisioning targets original user: $ORIGINAL_USER"
        export ANSIBLE_REMOTE_USER="$ORIGINAL_USER"
    fi
    
    # Run the playbook
    ansible-playbook \
        -i inventory/local \
        -e "profile=$profile" \
        -e "target_user=$ORIGINAL_USER" \
        -e "target_user_home=$ORIGINAL_HOME" \
        --vault-password-file="$LOCAL_VAULT_PASS_FILE" \
        site.yml
}

# Main execution
main() {
    log_info "Starting qyksys bootstrap..."
    
    # Detect OS
    OS_TYPE=$(detect_os)
    log_info "Detected OS: $OS_TYPE"
    
    # Install prerequisites if needed
    if ! command -v python3 >/dev/null 2>&1 || ! command -v git >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
        install_prerequisites "$OS_TYPE"
    fi
    
    # Clone the repository to temporary directory
    log_info "Cloning qyksys repository..."
    mkdir -p "$WORK_DIR"
    if ! git clone "$REPO_URL" "$WORK_DIR"; then
        log_error "Failed to clone repository from $REPO_URL"
        exit 1
    fi
    
    # Change to work directory
    cd "$WORK_DIR"
    log_success "Repository cloned to $WORK_DIR"
    
    # Install Ansible if not present
    if ! command -v ansible-playbook >/dev/null 2>&1; then
        install_ansible
    else
        log_info "Ansible already installed"
    fi
    
    # Setup vault password (using original user's home directory)
    LOCAL_VAULT_PASS_FILE="$ORIGINAL_HOME/.config/$PROJECT_NAME/vault_pass.txt"
    setup_vault_password
    
    # Select profile
    PROFILE=$(select_profile)
    
    # Run Ansible with original user context
    run_ansible "$PROFILE"
    
    log_success "Qyksys provisioning completed successfully!"
    log_info "Profile: $PROFILE"
    log_info "Vault password file: $LOCAL_VAULT_PASS_FILE"
    log_info "Temporary files will be cleaned up automatically"
}

# Run main function
main "$@"