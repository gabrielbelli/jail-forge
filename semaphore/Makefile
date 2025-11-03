# Makefile for Ansible Semaphore on BSD Jails
# Provides convenient shortcuts for common operations

.PHONY: help init deploy update backup snapshot restore destroy destroy-all check lint test clean

# Variables
ANSIBLE_PLAYBOOK := ansible-playbook
INVENTORY := inventory/hosts.yml
VAULT_PASS := --vault-password-file .vault_pass

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo '🚀 Common Operations:'
	@echo '  deploy              Full deployment'
	@echo '  snapshot            Quick ZFS snapshot'
	@echo '  backup              Full data backup'
	@echo '  restore             Restore from backup'
	@echo '  disaster-recovery   Complete rebuild from backup'
	@echo ''
	@echo '📋 All Available Targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

generate-secrets: ## Generate secure random secrets for deployment
	@./scripts/generate-secrets.sh

check: ## Check connectivity to BSD host
	ansible -i $(INVENTORY) -m ping jail_hosts

init: check ## Initialize and prepare BSD host for jails
	$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) playbooks/01-prepare-host.yml

deploy: ## Full deployment of Semaphore infrastructure
	$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) site.yml

deploy-db: ## Deploy only the database jail
	$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) playbooks/02-deploy-database.yml

deploy-app: ## Deploy only the Semaphore application jail
	$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) playbooks/03-deploy-semaphore.yml

update: ## Update Semaphore to a new version
	@read -p "Enter new version (e.g., v2.10.0): " version; \
	$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) playbooks/update-semaphore.yml -e "semaphore_new_version=$$version"

backup: ## Create data backup (IaC approach - data only)
	$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) playbooks/backup.yml

snapshot: ## Take instant ZFS snapshots (fast rollback capability)
	$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) playbooks/snapshot.yml

restore: ## Restore data from backup (interactive)
	$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) playbooks/restore.yml

disaster-recovery: ## Complete rebuild: deploy infrastructure + restore data
	$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) playbooks/disaster-recovery.yml

list-backups: ## List available backups
	@echo "Available backups in /var/backups/semaphore/:"
	@echo ""
	@ansible jail_hosts -i $(INVENTORY) -m shell -a "ls -lhtr /var/backups/semaphore/ 2>/dev/null | tail -n +2 || echo 'No backups found'" 2>/dev/null | grep -v "CHANGED\|rc=0\|DEPRECATION\|WARNING" | sed 's/^/  /' || echo "  No backups found"

verify: ## Verify deployment is working
	$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) playbooks/04-verify-deployment.yml

destroy: ## Destroy all jails (DANGEROUS!)
	@echo "⚠️  WARNING: This will destroy all Semaphore infrastructure!"
	@read -p "Are you sure? Type 'yes' to continue: " confirm; \
	if [ "$$confirm" = "yes" ]; then \
		$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) playbooks/destroy.yml -e confirm_destroy=yes; \
	else \
		echo "Cancelled."; \
	fi

destroy-all: ## Destroy EVERYTHING including all data (EXTREMELY DANGEROUS!)
	@echo "⚠️⚠️⚠️  EXTREME WARNING: This will PERMANENTLY destroy ALL data!"
	@echo "This includes:"
	@echo "  - All jails (semaphore-app, semaphore-db)"
	@echo "  - All databases and Semaphore data (IRREVERSIBLE!)"
	@echo "  - All ZFS datasets"
	@echo "  - All configurations"
	@echo ""
	@read -p "Type 'destroy-everything' to confirm PERMANENT destruction: " confirm; \
	if [ "$$confirm" = "destroy-everything" ]; then \
		$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) playbooks/destroy-all.yml -e confirm_destroy_all=destroy-everything; \
	else \
		echo "Cancelled. You must type exactly 'destroy-everything' to proceed."; \
	fi

lint: ## Run ansible-lint on all playbooks
	@command -v ansible-lint >/dev/null 2>&1 || { echo "ansible-lint not found. Install with: pip install ansible-lint"; exit 1; }
	ansible-lint site.yml playbooks/*.yml

test: ## Run syntax check on all playbooks
	$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) site.yml --syntax-check
	$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) playbooks/*.yml --syntax-check

status: ## Show status of jails
	@echo "Checking jail status on BSD host..."
	ansible jail_hosts -i $(INVENTORY) -m shell -a "jls -v"

logs-app: ## Show Semaphore application logs
	ansible jail_hosts -i $(INVENTORY) -m shell -a "jexec semaphore-app tail -f /var/log/semaphore/semaphore.log"

logs-db: ## Show PostgreSQL logs
	ansible jail_hosts -i $(INVENTORY) -m shell -a "jexec semaphore-db tail -f /var/db/postgres/data15/log/*.log"

shell-app: ## Open shell in Semaphore jail
	@echo "Opening shell in semaphore-app jail..."
	ansible jail_hosts -i $(INVENTORY) -m shell -a "jexec semaphore-app /bin/sh"

shell-db: ## Open shell in database jail
	@echo "Opening shell in semaphore-db jail..."
	ansible jail_hosts -i $(INVENTORY) -m shell -a "jexec semaphore-db /bin/sh"

clean: ## Clean up temporary files
	find . -type f -name '*.retry' -delete
	find . -type f -name '*.pyc' -delete
	find . -type d -name '__pycache__' -delete
	rm -rf /tmp/ansible_facts

vault-create: ## Create ansible vault for secrets
	ansible-vault create group_vars/all/vault.yml

vault-edit: ## Edit ansible vault
	ansible-vault edit group_vars/all/vault.yml

vault-encrypt: ## Encrypt a file with ansible vault
	@read -p "Enter file path to encrypt: " file; \
	ansible-vault encrypt $$file

vault-decrypt: ## Decrypt a file with ansible vault
	@read -p "Enter file path to decrypt: " file; \
	ansible-vault decrypt $$file

requirements: ## Install required Ansible collections and Python packages
	ansible-galaxy collection install community.general community.postgresql
	pip install psycopg2-binary

docs: ## Show documentation
	@echo "Documentation:"
	@echo "  README.md           - Getting started guide"
	@echo "  docs/architecture.md - Architecture overview"
	@echo "  docs/operations.md  - Operations guide"
	@echo ""
	@echo "Quick start:"
	@echo "  1. Edit inventory/hosts.yml with your BSD host IP"
	@echo "  2. make check"
	@echo "  3. make deploy"

.DEFAULT_GOAL := help
