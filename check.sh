#!/bin/bash
# Simple project structure validation

echo "Machine Provisioner - Project Structure Check"
echo "============================================="

errors=0

check_file() {
    if [[ -f "$1" ]]; then
        echo "✓ $1"
    else
        echo "✗ $1 (missing)"
        ((errors++))
    fi
}

check_dir() {
    if [[ -d "$1" ]]; then
        echo "✓ $1/"
    else
        echo "✗ $1/ (missing)"
        ((errors++))
    fi
}

echo
echo "Core Files:"
check_file "bootstrap.sh"
check_file "setup.sh"
check_file "site.yml"
check_file "ansible.cfg"
check_file "README.md"
check_file "Makefile"

echo
echo "Directories:"
check_dir "inventory"
check_dir "group_vars/all"
check_dir "roles"
check_dir "vault"

echo
echo "Roles:"
for role in common sudo ufw zsh ssh_client ssh_server; do
    check_dir "roles/$role/tasks"
    check_file "roles/$role/tasks/main.yml"
done

echo
echo "Configuration:"
check_file "group_vars/all/main.yml"
check_file "group_vars/all/vault.yml"
check_file "inventory/local"

echo
echo "Vault Files:"
check_file "vault/vault_pass.txt.vault"
check_file "vault/ssh_public_key.txt.vault"

echo
echo "Additional Files:"
check_file "roles/zsh/files/zshrc"
check_file "vault_example.yml"

echo
echo "============================================="
if [[ $errors -eq 0 ]]; then
    echo "✓ All files and directories are present!"
    echo "✓ Project structure validation passed."
    exit 0
else
    echo "✗ $errors missing files/directories found."
    echo "✗ Project structure validation failed."
    exit 1
fi