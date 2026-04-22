# Makefile for Jail Forge
# Project-level targets for shared infrastructure

.PHONY: help requirements

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

requirements: ## Install Ansible and required collections
	@command -v pip >/dev/null 2>&1 || { echo "Error: pip not found. Run: sudo pkg install -y py311-pip"; exit 1; }
	@command -v python3.11 >/dev/null 2>&1 || command -v python3 >/dev/null 2>&1 || { echo "Error: python3 not found. Run: sudo pkg install -y python311"; exit 1; }
	pip install -r requirements.txt
	ansible-galaxy collection install community.general community.postgresql
	@echo ""
	@echo "All requirements installed successfully."

.DEFAULT_GOAL := help
