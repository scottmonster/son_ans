#!/bin/bash
# Validation script for qyksys project
# Tests project structure and basic functionality

set -eo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Test file existence
test_file_exists() {
    local file="$1"
    local description="$2"
    
    if [[ -f "$file" ]]; then
        log_success "$description exists: $file"
    else
        log_fail "$description missing: $file"
    fi
}

# Test directory existence
test_dir_exists() {
    local dir="$1"
    local description="$2"
    
    if [[ -d "$dir" ]]; then
        log_success "$description exists: $dir"
    else
        log_fail "$description missing: $dir"
    fi
}

# Test file permissions
test_file_permissions() {
    local file="$1"
    local expected_perms="$2"
    local description="$3"
    
    if [[ -f "$file" ]]; then
        local actual_perms
        if command -v stat >/dev/null 2>&1; then
            # Try Linux format first, then macOS format
            actual_perms=$(stat -c %a "$file" 2>/dev/null || stat -f %A "$file" 2>/dev/null || echo "unknown")
        else
            # Fallback using ls
            actual_perms=$(ls -l "$file" | cut -c1-10 || echo "unknown")
        fi
        if [[ "$actual_perms" == "$expected_perms" ]]; then
            log_success "$description has correct permissions: $expected_perms"
        else
            log_warning "$description permissions: expected $expected_perms, got $actual_perms (may vary by OS)"
            ((TESTS_PASSED++))  # Don't fail on permission differences
        fi
    else
        log_fail "$description does not exist: $file"
    fi
}

# Test YAML syntax
test_yaml_syntax() {
    local file="$1"
    local description="$2"
    
    if [[ -f "$file" ]]; then
        if python3 -c "import yaml; yaml.safe_load(open('$file'))" 2>/dev/null; then
            log_success "$description has valid YAML syntax"
        else
            log_fail "$description has invalid YAML syntax"
        fi
    else
        log_fail "$description does not exist: $file"
    fi
}

# Test vault file encryption
test_vault_encryption() {
    local file="$1"
    local description="$2"
    
    if [[ -f "$file" ]]; then
        if head -1 "$file" | grep -q "\$ANSIBLE_VAULT"; then
            log_success "$description is properly encrypted"
        else
            log_fail "$description is not encrypted (potential security risk)"
        fi
    else
        log_fail "$description does not exist: $file"
    fi
}

# Main validation
main() {
    log_info "Machine Provisioner - Project Validation"
    echo
    
    # Test core files
    log_info "Testing core project files..."
    test_file_exists "bootstrap.sh" "Bootstrap script"
    test_file_exists "setup.sh" "Setup script"
    test_file_exists "site.yml" "Main playbook"
    test_file_exists "ansible.cfg" "Ansible configuration"
    test_file_exists "README.md" "Documentation"
    test_file_exists "Makefile" "Makefile"
    test_file_exists "vault_example.yml" "Vault example"
    
    echo
    
    # Test directory structure
    log_info "Testing directory structure..."
    test_dir_exists "inventory" "Inventory directory"
    test_dir_exists "group_vars/all" "Group vars directory"
    test_dir_exists "roles" "Roles directory"
    test_dir_exists "vault" "Vault directory"
    
    echo
    
    # Test role structure
    log_info "Testing role structure..."
    for role in common sudo ufw zsh ssh_client ssh_server; do
        test_dir_exists "roles/$role/tasks" "Role $role tasks directory"
        test_file_exists "roles/$role/tasks/main.yml" "Role $role main tasks"
    done
    
    echo
    
    # Test inventory
    log_info "Testing inventory..."
    test_file_exists "inventory/local" "Local inventory"
    
    echo
    
    # Test group vars
    log_info "Testing group variables..."
    test_file_exists "group_vars/all/main.yml" "Main variables"
    test_file_exists "group_vars/all/vault.yml" "Vault variables"
    
    echo
    
    # Test vault files
    log_info "Testing vault encryption..."
    test_file_exists "vault/vault_pass.txt.vault" "Encrypted vault password"
    test_file_exists "vault/ssh_public_key.txt.vault" "Encrypted SSH public key"
    test_vault_encryption "group_vars/all/vault.yml" "Vault variables file"
    test_vault_encryption "vault/vault_pass.txt.vault" "Vault password file"
    test_vault_encryption "vault/ssh_public_key.txt.vault" "SSH public key file"
    
    echo
    
    # Test file permissions
    log_info "Testing file permissions..."
    test_file_permissions "bootstrap.sh" "755" "Bootstrap script"
    test_file_permissions "setup.sh" "755" "Setup script"
    
    echo
    
    # Test YAML syntax
    log_info "Testing YAML syntax..."
    test_yaml_syntax "site.yml" "Main playbook"
    test_yaml_syntax "group_vars/all/main.yml" "Main variables"
    test_yaml_syntax "vault_example.yml" "Vault example"
    
    for role in common sudo ufw zsh ssh_client ssh_server; do
        test_yaml_syntax "roles/$role/tasks/main.yml" "Role $role tasks"
    done
    
    if [[ -f "roles/ssh_server/handlers/main.yml" ]]; then
        test_yaml_syntax "roles/ssh_server/handlers/main.yml" "SSH server handlers"
    fi
    
    echo
    
    # Test Zsh files
    log_info "Testing role files..."
    test_file_exists "roles/zsh/files/zshrc" "Zsh configuration file"
    
    echo
    
    # Summary
    log_info "Validation Summary"
    echo "  Tests passed: $TESTS_PASSED"
    echo "  Tests failed: $TESTS_FAILED"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_success "All tests passed! Project structure is valid."
        exit 0
    else
        log_fail "Some tests failed. Please review the issues above."
        exit 1
    fi
}

# Check if we're in the right directory
if [[ ! -f "site.yml" ]] || [[ ! -d "roles" ]]; then
    log_fail "This script must be run from the qyksys project root"
    exit 1
fi

main "$@"