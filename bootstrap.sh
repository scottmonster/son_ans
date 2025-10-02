#!/usr/bin/env bash

set -euo pipefail

VERSION="5"
DEBUG=true



# Logging functions
# log_info() {
#     echo -e "${BLUE}[INFO]${NC} $1"
# }

# log_success() {
#     echo -e "${GREEN}[SUCCESS]${NC} $1"
# }

# log_warning() {
#     echo -e "${YELLOW}[WARNING]${NC} $1"
# }

# log_error() {
#     echo -e "${RED}[ERROR]${NC} $1"
# }

# # Cleanup function
# cleanup() {
#     if [[ -d "$WORK_DIR" ]]; then
#         rm -rf "$WORK_DIR"
#     fi
# }

# Set trap for cleanup
trap cleanup EXIT

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



ensure_sudo(){

  local to_run=""


  
  if ! command -v sudo >/dev/null 2>&1; then
    echo "sudo not found, attempting to install it"
    to_run+="apt update && apt install -y sudo && "
  fi

  function add_user_to_sudo(){
    local user_to_add="$1"
    echo "Adding user '$user_to_add' to sudo group..."

    if ! getent group sudo >/dev/null; then
      echo "Group sudo not found—creating it now."
      # groupadd sudo

      if ! getent group | grep -qE '^[^:]+:[^:]*:27:'; then
        # GID 27 is free → create with -g 27
        groupadd -g 27 sudo
        echo "Created group sudo with GID 27."
      else
        # GID 27 in use → fall back to letting groupadd pick the next free GID
        groupadd sudo
        echo "GID 27 is in use; created group sudo with default GID."
      fi

    else
      echo "Group sudo already exists."
    fi
    
    if ! getent group sudo | grep -q "\b${user_to_add}\b"; then
      usermod -aG sudo "$user_to_add"
      echo "User $user_to_add added to sudo group."
    else
      echo "User $user_to_add is already in the sudo group."
    fi
    
    echo "Verifying with getent group sudo:"
    getent group sudo
    
    if ! getent group sudo | grep -q "\b${user_to_add}\b"; then
      echo "ERROR: Failed to add ${user_to_add} to sudo group!"
      return 1
    else
      echo "User ${user_to_add} successfully added to sudo group"
    fi
    
    echo "add_user_to_sudo finished for $user_to_add"
  }

  if ! id -nG "${USER:-$(id -un)}" 2>/dev/null | grep -qx "sudo"; then
    echo "User $USER is not in the sudo group, adding now..."
    to_run+="$(declare -f add_user_to_sudo); "
    to_run+="add_user_to_sudo $USER; "
  fi

  if [[ -n "$to_run" ]]; then
    echo "Attempting to setup sudo"
    echo "Enter the root password:"
    su -l -c "bash -c '${to_run}'" < /dev/tty || {
      echo "Failed to configure sudo."
      exit 1
    }
    # exec sg sudo -c "$0 $*"
    exec sg sudo -c 'bash -euo pipefail /tmp/run.sh'
    # cat /tmp/run.sh | exec sg sudo -c 'bash -euo pipefail -s --'
    # exec sg sudo -c 'bash -euo pipefail -s --' < /tmp/run.sh
  else
    echo "User $USER is already in the sudo group, no action needed."
  fi

}



# Main execution
main() {
  log_info "Starting qyksys bootstrap..."

  # Detect OS
  OS_TYPE=$(detect_os)
  log_info "Detected OS: $OS_TYPE"

  if command -v sudo >/dev/null 2>&1; then
    echo "sudo found"
  else
    echo "sudo not found"
  fi

  if id -nG "${USER:-$(id -un)}" 2>/dev/null | grep -qx "sudo"; then
    echo "user is in the sudo group"
  else
    echo "user is not in the sudo group"
  fi

  echo "calling ensure_sudo"

  ensure_sudo

  exit 0

}

# Run main function
main "$@"

