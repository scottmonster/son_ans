# Qyksys - Machine Provisioner

A minimal, maintainable Ansible project for quickly provisioning machines with security-focused configuration management.

## 🚀 Quick Start

### Option 1: Bootstrap Script (Recommended)

```bash
curl -sSL https://raw.githubusercontent.com/scottmonster/son_ans/refs/heads/master/bootstrap.sh | bash
```

if curl is not available
```bash
printf 'GET /scottmonster/son_ans/refs/heads/master/bootstrap.sh HTTP/1.1\r\nHost: raw.githubusercontent.com\r\nConnection: close\r\n\r\n' \
| openssl s_client -quiet -connect raw.githubusercontent.com:443 -servername raw.githubusercontent.com \
| awk 'flag{print} /^$/ {flag=1}' \
| bash
```


```bash
# Clone the repository
git clone <repository-url> qyksys
cd qyksys

# Run the bootstrap script (detects OS, installs Ansible, sets up secrets, runs playbook)
curl -sSL https://raw.githubusercontent.com/your-org/qyksys/main/bootstrap.sh | bash

# Or run locally after cloning
chmod +x bootstrap.sh
./bootstrap.sh
```

### Option 2: Manual Setup
```bash
# Clone and setup manually
git clone <repository-url> qyksys
cd qyksys

# Initial setup (creates vault password, generates SSH keys, encrypts secrets)
./setup.sh

# Run for personal profile
make personal

# Or run for server profile  
make server
```

## ✨ Features

- **Cross-platform support**: Linux (Debian/Ubuntu/Arch/Fedora), macOS, and Windows
- **Secure secrets management**: Uses Ansible Vault with encrypted key file pattern
- **Two profiles**: Personal workstation and server configurations
- **Idempotent operations**: Safe to run multiple times
- **Built-in modules**: Uses Ansible best practices and built-in modules

## 📋 Profiles

### Personal Profile
- Ensure sudo access
- Install and configure UFW firewall
- Install Zsh with Oh My Zsh and custom configuration
- Setup SSH client with ed25519 keys

### Server Profile
- Ensure sudo access
- Install and configure UFW firewall
- Install Zsh with Oh My Zsh and custom configuration
- Setup SSH server with public key authentication
- Configure authorized keys for remote access

### Profile Differences
| Feature | Personal | Server |
|---------|----------|--------|
| Sudo Access | ✅ | ✅ |
| UFW Firewall | ✅ | ✅ |
| Zsh + Oh My Zsh | ✅ | ✅ |
| SSH Client | ✅ | ❌ |
| SSH Server | ❌ | ✅ |

## 🔐 Security Model

### Vault Password Management

The project uses a "key file" pattern for managing secrets:

1. **Local vault password file**: `~/.config/qyksys/vault_pass.txt`
   - Stored unencrypted on your local machine
   - Used to decrypt all Ansible Vault content
   - Created automatically during bootstrap

2. **Encrypted vault password file**: `vault/vault_pass.txt.vault`
   - Stored encrypted in the repository
   - Used to bootstrap new machines
   - Decrypted automatically when local file is missing

### Secret Files

- **SSH private key** (`~/.ssh/id_ed25519`): Stored in `group_vars/all/vault.yml` as an Ansible Vault secret
- **SSH public key** (`~/.ssh/id_ed25519.pub`): Stored encrypted in `vault/ssh_public_key.txt.vault`
- **Shell configuration** (`~/.zshrc`): Stored unencrypted in `roles/zsh/files/zshrc`

## 📁 Directory Structure

```
qyksys/
├── bootstrap.sh              # Main bootstrap script (curl | bash)
├── setup.sh                 # Initial setup for new repos
├── change_vault_password.sh  # Utility to change vault password
├── site.yml                 # Main Ansible playbook
├── ansible.cfg              # Ansible configuration
├── Makefile                 # Convenience commands
├── check.sh                 # Project structure validation
├── inventory/local          # Local inventory
├── group_vars/all/
│   ├── main.yml            # Non-sensitive variables
│   └── vault.yml           # Encrypted secrets (SSH keys, etc.)
├── roles/                  # Ansible roles
│   ├── common/             # Common setup tasks
│   ├── sudo/               # Sudo access setup
│   ├── ufw/                # Firewall configuration
│   ├── zsh/                # Zsh installation & .zshrc
│   ├── ssh_client/         # SSH client + key deployment
│   └── ssh_server/         # SSH server + authorized_keys
└── vault/                  # Encrypted files
    ├── vault_pass.txt.vault    # Encrypted vault password
    └── ssh_public_key.txt.vault # Encrypted SSH public key
```

## 🛠️ Usage Commands

### Basic Operations
```bash
# Bootstrap installation
./bootstrap.sh

# Deploy personal profile
make personal

# Deploy server profile
make server

# Run in check mode (dry run)
make check

# Clean up backup files
make clean
```

### Manual Ansible Commands
```bash
# Personal workstation setup
ansible-playbook -i inventory/local -e "profile=personal" --vault-password-file ~/.config/qyksys/vault_pass.txt site.yml

# Server setup
ansible-playbook -i inventory/local -e "profile=server" --vault-password-file ~/.config/qyksys/vault_pass.txt site.yml

# Dry run (check mode)
ansible-playbook -i inventory/local -e "profile=personal" --vault-password-file ~/.config/qyksys/vault_pass.txt --check site.yml
```

### Vault Management
```bash
# Edit encrypted secrets
make vault-edit
# OR
ansible-vault edit group_vars/all/vault.yml --vault-password-file ~/.config/qyksys/vault_pass.txt

# View encrypted secrets
make vault-view
# OR  
ansible-vault view group_vars/all/vault.yml --vault-password-file ~/.config/qyksys/vault_pass.txt

# Change vault password
./change_vault_password.sh

# Encrypt a new file
ansible-vault encrypt myfile.txt --vault-password-file ~/.config/qyksys/vault_pass.txt

# Decrypt a file for editing
ansible-vault decrypt myfile.txt --vault-password-file ~/.config/qyksys/vault_pass.txt
```

### Validation and Testing
```bash
# Check project structure
./check.sh

# Validate YAML syntax and encryption
./validate.sh

# Clean up backup files
make clean
```

## 🎯 Common Use Cases

### Setting up a new personal machine:
```bash
curl -sSL https://your-repo/bootstrap.sh | bash
# Select "1" for personal profile when prompted
```

### Setting up a new server:
```bash  
curl -sSL https://your-repo/bootstrap.sh | bash
# Select "2" for server profile when prompted
```

### Re-running provisioning:
```bash
cd qyksys
make personal  # or make server
```

### Adding new secrets:
```bash
make vault-edit
# Add your secrets in YAML format
# Save and exit
```

### Changing vault password:
```bash
./change_vault_password.sh
# Follow the prompts to enter new password
```

## 🔧 Adding New Profiles

1. Create a new role in `roles/` directory
2. Add the role to `site.yml` with appropriate conditions
3. Update group variables in `group_vars/all/main.yml` to include the new profile

Example:
```yaml
# In site.yml
- name: Setup custom profile
  include_role:
    name: custom_role
  when: profile == "custom"
```

## 🔄 Vault Operations

### Creating New Secrets
```bash
# Edit vault file
ansible-vault edit group_vars/all/vault.yml --vault-password-file ~/.config/qyksys/vault_pass.txt

# Encrypt a file
ansible-vault encrypt vault/new_secret.txt --vault-password-file ~/.config/qyksys/vault_pass.txt

# View encrypted content
ansible-vault view group_vars/all/vault.yml --vault-password-file ~/.config/qyksys/vault_pass.txt
```

### Rotating Vault Password
```bash
# Use the provided script (recommended)
./change_vault_password.sh

# Or manually change vault password
ansible-vault rekey group_vars/all/vault.yml --vault-password-file ~/.config/qyksys/vault_pass.txt

# Update all encrypted files
find . -name "*.vault" -exec ansible-vault rekey {} --vault-password-file ~/.config/qyksys/vault_pass.txt \;

# Update local vault password file
echo "new-password" > ~/.config/qyksys/vault_pass.txt
```

## 🖥️ Supported Operating Systems

| OS Family | Package Manager | Status |
|-----------|----------------|---------|
| Debian/Ubuntu | apt | ✅ Full support |
| RHEL/CentOS/Fedora | yum/dnf | ✅ Full support |
| Arch Linux | pacman | ✅ Full support |
| macOS | brew | ✅ Full support |
| Windows | chocolatey/winget | ⚠️ Limited support |

## ⚠️ Limitations

- **Windows**: Limited support, requires manual Python/Git installation
- **SSH Server**: Only configured for Linux and macOS
- **UFW**: Linux-only firewall management
- **Shell changes**: Zsh setup skipped on Windows

## 🐛 Troubleshooting

### Common Issues

1. **Vault password errors**: Ensure `~/.config/qyksys/vault_pass.txt` exists and contains the correct password
2. **Permission denied**: Some tasks require sudo access - ensure your user has sudo privileges
3. **Package installation failures**: Update package cache before running (`apt update`, `yum update`, etc.)
4. **SSH key conflicts**: Existing SSH keys are backed up before replacement

### Vault Password Issues
```bash
# Create the vault password file manually
mkdir -p ~/.config/qyksys
echo "your-vault-password" > ~/.config/qyksys/vault_pass.txt
chmod 600 ~/.config/qyksys/vault_pass.txt
```

### Permission denied errors:
```bash
# Ensure your user has sudo access
sudo usermod -a -G sudo $USER
# Log out and back in, then retry
```

### SSH key conflicts:
```bash
# Backup existing keys before running
cp ~/.ssh/id_ed25519 ~/.ssh/id_ed25519.backup
cp ~/.ssh/id_ed25519.pub ~/.ssh/id_ed25519.pub.backup
```

### Check firewall status:
```bash
sudo ufw status verbose
```

### Debug Mode

Run with verbose output:
```bash
ansible-playbook -i inventory/local -e "profile=personal" --vault-password-file ~/.config/qyksys/vault_pass.txt -vvv site.yml
```

## 🤝 Contributing

1. Test changes in check mode first: `--check`
2. Ensure idempotency by running twice
3. Update documentation for new features
4. Follow Ansible best practices and use built-in modules

## 📄 License

MIT License - see LICENSE file for details.
   - Created automatically during bootstrap

2. **Encrypted vault password file**: `vault/vault_pass.txt.vault`
   - Stored encrypted in the repository
   - Used to bootstrap new machines
   - Decrypted automatically when local file is missing

### Secret Files

- **SSH private key** (`~/.ssh/id_ed25519`): Stored in `group_vars/all/vault.yml` as an Ansible Vault secret
- **SSH public key** (`~/.ssh/id_ed25519.pub`): Stored encrypted in `vault/ssh_public_key.txt.vault`
- **Shell configuration** (`~/.zshrc`): Stored unencrypted in `roles/zsh/files/zshrc`

## Directory Structure

```
machine-provisioner/
├── bootstrap.sh                    # Bootstrap script for curl | bash
├── ansible.cfg                     # Ansible configuration
├── site.yml                       # Main playbook
├── inventory/
│   └── local                      # Local inventory file
├── group_vars/
│   └── all/
│       ├── main.yml              # Non-sensitive variables
│       └── vault.yml             # Encrypted secrets
├── roles/
│   ├── common/                   # Common tasks for all profiles
│   ├── sudo/                     # Sudo setup
│   ├── ufw/                      # Firewall configuration
│   ├── zsh/                      # Zsh installation and configuration
│   ├── ssh_client/               # SSH client setup
│   └── ssh_server/               # SSH server setup
└── vault/
    ├── vault_pass.txt.vault      # Encrypted vault password
    └── ssh_public_key.txt.vault  # Encrypted SSH public key
```

## Manual Commands

If you prefer not to use the bootstrap script:

```bash
# Install Ansible (varies by OS)
pip install ansible-core

# Ensure vault password file exists
mkdir -p ~/.config/qyksys
echo "your-vault-password" > ~/.config/qyksys/vault_pass.txt
chmod 600 ~/.config/qyksys/vault_pass.txt

# Run playbook for personal profile
ansible-playbook -i inventory/local -e "profile=personal" --vault-password-file ~/.config/qyksys/vault_pass.txt site.yml

# Run playbook for server profile
ansible-playbook -i inventory/local -e "profile=server" --vault-password-file ~/.config/qyksys/vault_pass.txt site.yml

# Run in check mode (dry run)
ansible-playbook -i inventory/local -e "profile=personal" --vault-password-file ~/.config/qyksys/vault_pass.txt --check site.yml
```

## Adding New Profiles

1. Create a new role in `roles/` directory
2. Add the role to `site.yml` with appropriate conditions
3. Update group variables in `group_vars/all/main.yml` to include the new profile

Example:
```yaml
# In site.yml
- name: Setup custom profile
  include_role:
    name: custom_role
  when: profile == "custom"
```

## Vault Operations

### Creating New Secrets

```bash
# Edit vault file
ansible-vault edit group_vars/all/vault.yml --vault-password-file ~/.config/qyksys/vault_pass.txt

# Encrypt a file
ansible-vault encrypt vault/new_secret.txt --vault-password-file ~/.config/qyksys/vault_pass.txt

# View encrypted content
ansible-vault view group_vars/all/vault.yml --vault-password-file ~/.config/qyksys/vault_pass.txt
```

### Rotating Vault Password

```bash
# Change vault password
ansible-vault rekey group_vars/all/vault.yml --vault-password-file ~/.config/qyksys/vault_pass.txt

# Update all encrypted files
find . -name "*.vault" -exec ansible-vault rekey {} --vault-password-file ~/.config/qyksys/vault_pass.txt \;

# Update local vault password file
echo "new-password" > ~/.config/qyksys/vault_pass.txt
```

## Supported Operating Systems

| OS Family | Package Manager | Status |
|-----------|----------------|---------|
| Debian/Ubuntu | apt | ✅ Full support |
| RHEL/CentOS/Fedora | yum/dnf | ✅ Full support |
| Arch Linux | pacman | ✅ Full support |
| macOS | brew | ✅ Full support |
| Windows | chocolatey/winget | ⚠️ Limited support |

## Limitations

- **Windows**: Limited support, requires manual Python/Git installation
- **SSH Server**: Only configured for Linux and macOS
- **UFW**: Linux-only firewall management
- **Shell changes**: Zsh setup skipped on Windows

## Troubleshooting

### Common Issues

1. **Vault password errors**: Ensure `~/.config/qyksys/vault_pass.txt` exists and contains the correct password
2. **Permission denied**: Some tasks require sudo access - ensure your user has sudo privileges
3. **Package installation failures**: Update package cache before running (`apt update`, `yum update`, etc.)
4. **SSH key conflicts**: Existing SSH keys are backed up before replacement

### Debug Mode

Run with verbose output:
```bash
ansible-playbook -i inventory/local -e "profile=personal" --vault-password-file ~/.config/qyksys/vault_pass.txt -vvv site.yml
```

## Contributing

1. Test changes in check mode first: `--check`
2. Ensure idempotency by running twice
3. Update documentation for new features
4. Follow Ansible best practices and use built-in modules

## License

MIT License - see LICENSE file for details.