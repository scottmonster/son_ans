# Configuration Changes Summary

## Changes Made

### 1. Project Name Change
- Changed from `machine-provisioner` to `qyksys`
- Updated in all configuration files, documentation, and scripts

### 2. Vault Password File Location
- **Old location**: `~/.config/machine-provisioner/vault_pass.txt`
- **New location**: `~/.config/qyksys/vault_pass.txt`

### 3. SSH Key Configuration
- **SSH private key**: `~/.ssh/id_ed25519` (explicitly specified)
- **SSH public key**: `~/.ssh/id_ed25519.pub` (explicitly specified)
- Removed dynamic key type variables for clarity

## Files Updated

### Configuration Files
- `ansible.cfg` - Updated vault_password_file location
- `group_vars/all/main.yml` - Updated project name and SSH key paths
- `inventory/local` - No changes needed

### Scripts
- `bootstrap.sh` - Updated PROJECT_NAME and vault file location
- `setup.sh` - Updated PROJECT_NAME and vault file location  
- `validate.sh` - Updated project name references
- `check.sh` - No changes needed (structure-agnostic)

### Build Files
- `Makefile` - Updated all vault password file paths in targets:
  - `personal`
  - `server` 
  - `check`
  - `vault-edit`
  - `vault-view`
  - `vault-check`

### Documentation
- `README.md` - Updated all references to vault password location and project name
- `USAGE.md` - Updated all command examples and file paths
- `vault_example.yml` - Updated vault password location comment

### Vault Files
- `vault/vault_pass.txt.vault` - No changes (encrypted content)
- `vault/ssh_public_key.txt.vault` - No changes (encrypted content)
- `group_vars/all/vault.yml` - No changes (encrypted content)

## Key Benefits

1. **Cleaner naming**: `qyksys` is shorter and more distinctive
2. **Explicit SSH keys**: No more dynamic key type variables - always uses ed25519
3. **Consistent vault location**: All references now point to `~/.config/qyksys/vault_pass.txt`
4. **Maintained functionality**: All existing features work exactly the same

## Verification

✓ Project structure validation passes
✓ All SSH key paths are explicitly set to ed25519
✓ All vault password references updated consistently
✓ Documentation matches implementation

## Usage Examples

```bash
# Bootstrap (unchanged)
./bootstrap.sh

# Manual commands (updated paths)
ansible-playbook -i inventory/local -e "profile=personal" --vault-password-file ~/.config/qyksys/vault_pass.txt site.yml

# Vault management (updated paths)
make vault-edit
make vault-view

# SSH keys will be placed at:
# ~/.ssh/id_ed25519 (private key)
# ~/.ssh/id_ed25519.pub (public key)
```

All changes maintain backward compatibility with the existing encrypted vault files and project structure.