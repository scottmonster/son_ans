#!/usr/bin/env bash


VERSION="5"
DEBUG=true



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
    su -l -c "bash -c '${to_run}'"|| {
      echo "Failed to configure sudo."
      echo "Check the logs in $PWD/$SAFETY_LOG for more details."
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

run_priveleged(){

  # id -nG $USER 2>/dev/null | grep 'sudo', use sudo
  if id -nG "${USER:-$(id -un)}" 2>/dev/null | grep -qx "sudo"; then
    sudo "$@"
    return
  elif command -v su >/dev/null 2>&1; then
    log "Elevating with su because current user lacks sudo group membership"
    local current_dir cmd tty_device
    current_dir=$(pwd)
    cmd=$(printf ' %q' "$@")
    cmd=${cmd# }
    tty_device=$(tty 2>/dev/null || true)

    if [ -n "$tty_device" ] && [ "$tty_device" != "not a tty" ]; then
      su root -c "cd $(printf '%q' "$current_dir") && $cmd" < "$tty_device"
    elif [ -r /dev/tty ]; then
      su root -c "cd $(printf '%q' "$current_dir") && $cmd" < /dev/tty
    else
      err "su fallback requires an interactive terminal. Please run bootstrap from a tty or configure sudo."
      exit 1
    fi
    return
  else
    log_error "Cannot gain root privileges. Please run this script as root or ensure your user is in the sudo group."
    exit 1
  fi

}

ensure_deps(){

  deps=(git curl ansible)
  missing_deps=()
  for dep in "${deps[@]}"; do
      if ! command -v "$dep" >/dev/null 2>&1; then
          missing_deps+=("$dep")
      fi
  done



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

