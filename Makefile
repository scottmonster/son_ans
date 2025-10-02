.PHONY: help install check clean personal server vault-edit vault-view

# Default target
help:
	@echo "Qyksys - Available targets:"
	@echo ""
	@echo "  install      - Run bootstrap script"
	@echo "  personal     - Deploy personal profile"
	@echo "  server       - Deploy server profile"
	@echo "  check        - Run playbook in check mode (dry run)"
	@echo "  clean        - Clean up backup files"
	@echo "  vault-edit   - Edit encrypted vault file"
	@echo "  vault-view   - View encrypted vault file"
	@echo ""
	@echo "Prerequisites:"
	@echo "  - Ansible must be installed"
	@echo "  - Vault password file must exist at ~/.config/qyksys/vault_pass.txt"

# Bootstrap installation
install:
	./bootstrap.sh

# Deploy personal profile
personal:
	ansible-playbook -i inventory/local -e "profile=personal" --vault-password-file ~/.config/qyksys/vault_pass.txt site.yml

# Deploy server profile
server:
	ansible-playbook -i inventory/local -e "profile=server" --vault-password-file ~/.config/qyksys/vault_pass.txt site.yml

# Run in check mode (dry run)
check:
	ansible-playbook -i inventory/local -e "profile=personal" --vault-password-file ~/.config/qyksys/vault_pass.txt --check site.yml

# Clean up backup files
clean:
	find . -name "*.backup" -delete
	find . -name "*.bak" -delete
	find . -name "*.tmp" -delete
	find . -name "*.retry" -delete

# Edit vault file
vault-edit:
	ansible-vault edit group_vars/all/vault.yml --vault-password-file ~/.config/qyksys/vault_pass.txt

# View vault file
vault-view:
	ansible-vault view group_vars/all/vault.yml --vault-password-file ~/.config/qyksys/vault_pass.txt

# Validate vault password file
vault-check:
	@if [ ! -f ~/.config/qyksys/vault_pass.txt ]; then \
		echo "ERROR: Vault password file not found at ~/.config/qyksys/vault_pass.txt"; \
		echo "Run './bootstrap.sh' or create the file manually"; \
		exit 1; \
	else \
		echo "Vault password file found"; \
	fi