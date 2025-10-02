#!/usr/bin/env bash

set -euo pipefail

VERSION="5"
DEBUG=true


RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
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

# # Cleanup function
cleanup() {
  echo "Cleaning up..."
}

# Set trap for cleanup
trap cleanup EXIT

# Detect OS
get_os() {
  # Prefer os-release if present (most modern distros)
  if [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    # ID like: ubuntu, debian, pop, linuxmint, fedora, rhel, centos, arch, manjaro, opensuse-leap, etc.
    case "${ID:-}" in
      ubuntu)    echo "ubuntu"; return 0 ;;
      debian)    echo "debian"; return 0 ;;
      pop)       echo "pop_os"; return 0 ;;
      linuxmint) echo "linuxmint"; return 0 ;;
      elementary)echo "elementary"; return 0 ;;
      raspbian)  echo "raspbian"; return 0 ;;
      fedora)    echo "fedora"; return 0 ;;
      rhel)      echo "redhat"; return 0 ;;
      centos)    echo "centos"; return 0 ;;
      rocky)     echo "rocky"; return 0 ;;
      almalinux) echo "almalinux"; return 0 ;;
      arch)      echo "arch"; return 0 ;;
      manjaro)   echo "manjaro"; return 0 ;;
      opensuse*|sles)
                 echo "suse"; return 0 ;;
    esac

    # Fall back to ID_LIKE if ID wasn’t matched
    case "${ID_LIKE:-}" in
      *debian*)  # includes ubuntu, pop_os, mint families
                 # try to be more specific if NAME/VERSION/LIKE give hints
                 if [ "${ID_LIKE#*ubuntu}" != "$ID_LIKE" ]; then
                   echo "ubuntu-like"
                 else
                   echo "debian-like"
                 fi
                 return 0
                 ;;
      *rhel*|*fedora*|*centos*)
                 echo "redhat-like"; return 0 ;;
      *arch*)    echo "arch-like"; return 0 ;;
      *suse*)    echo "suse-like"; return 0 ;;
    esac
  fi

  # If os-release missing or inconclusive, use package managers
  case "$OSTYPE" in
    linux-gnu*)
      if command -v apt-get >/dev/null 2>&1; then
        # Try lsb_release for finer detail if installed
        if command -v lsb_release >/dev/null 2>&1; then
          dist_id=$(lsb_release -si 2>/dev/null | tr '[:upper:]' '[:lower:]')
          case "$dist_id" in
            ubuntu)    echo "ubuntu" ;;
            debian)    echo "debian" ;;
            pop)       echo "pop_os" ;;
            linuxmint) echo "linuxmint" ;;
            *)         echo "debian-like" ;;
          esac
        else
          echo "debian-like"
        fi
      elif command -v dnf >/dev/null 2>&1 || command -v yum >/dev/null 2>&1; then
        echo "redhat-like"
      elif command -v pacman >/dev/null 2>&1; then
        echo "arch"
      elif command -v zypper >/dev/null 2>&1; then
        echo "suse"
      else
        echo "linux"
      fi
      ;;
    darwin*) echo "macos" ;;
    cygwin*|msys*|win32*) echo "windows" ;;
    *) echo "unknown" ;;
  esac
}

get_install_cmd() {
  local os_type="$1"
  case "$os_type" in
    ubuntu|debian|pop_os|linuxmint|elementary|raspbian|ubuntu-like|debian-like)
      echo "apt-get install -y"
      ;;
    fedora)
      echo "dnf install -y"
      ;;
    redhat|centos|rocky|almalinux|redhat-like)
      if command -v dnf >/dev/null 2>&1; then
        echo "dnf install -y"
      else
        echo "yum install -y"
      fi
      ;;
    suse|suse-like)
      echo "zypper install -y"
      ;;
    arch|manjaro|arch-like)
      echo "pacman -S --noconfirm"
      ;;
    macos)
      echo "brew install"
      ;;
    windows)
      echo "choco install -y"
      ;;
    *)
      # Unknown: return empty to signal caller to handle it
      echo ""
      ;;
  esac
}


ensure_sudo(){

  local to_run=""


  
  if ! command -v sudo >/dev/null 2>&1; then
    echo "sudo not found, attempting to install it"
    local os
    os=$(get_os)
    local install_cmd
    install_cmd=$(get_install_cmd "$os")
    to_run+="$install_cmd sudo && "
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
  OS=$(get_os)
  log_info "Detected OS: $OS"


  if ! sudo -v; then
    echo "sudo not usable (validation failed)"
    echo "calling ensure_sudo"
    # do something (fallback, exit, etc.)
    ensure_sudo
  else
    echo "sudo is usable"
  fi


  exit 0

}

# Run main function
main "$@"

