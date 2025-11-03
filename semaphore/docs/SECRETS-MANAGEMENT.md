# Secrets Management Guide

All secrets and sensitive configuration are centralized in `group_vars/all/secrets.yml` for easy management and security.

## Overview

**One file to rule them all:**  `group_vars/all/secrets.yml`

This file contains:
- Database passwords
- Semaphore admin credentials
- Semaphore encryption keys
- TLS certificate configuration
- Network settings
- All infrastructure configuration

## Quick Start

### 1. Edit Secrets File

```bash
cd semaphore-ansible
vim group_vars/all/secrets.yml
```

**Minimum required changes:**

```yaml
# Database
semaphore_db_password: "YOUR_STRONG_PASSWORD_HERE"

# Semaphore Admin
semaphore_admin_email: "your-email@example.com"
semaphore_admin_password: "YOUR_ADMIN_PASSWORD_HERE"

# Encryption Keys (generate with: openssl rand -hex 32)
semaphore_cookie_hash: "YOUR_RANDOM_32_CHAR_HEX"
semaphore_cookie_encryption: "YOUR_RANDOM_32_CHAR_HEX"
semaphore_access_key_encryption: "YOUR_RANDOM_32_CHAR_HEX"

# Network (update with your environment)
jail_ip_database: "192.168.1.50"
jail_ip_semaphore: "192.168.1.51"
jail_ip_nginx: "192.168.1.52"
```

### 2. Generate Strong Secrets

```bash
# Generate passwords
openssl rand -base64 32

# Generate encryption keys (32 chars hex)
openssl rand -hex 32
```

### 3. Encrypt the Secrets File

**IMPORTANT:** Always encrypt before committing to git!

```bash
# Encrypt
ansible-vault encrypt group_vars/all/secrets.yml

# You'll be prompted for a vault password
# REMEMBER THIS PASSWORD!
```

### 4. Deploy with Encrypted Secrets

```bash
# Option A: Prompt for password
ansible-playbook -i inventory/hosts.yml site.yml --ask-vault-pass

# Option B: Use password file
echo "your-vault-password" > .vault_pass
chmod 600 .vault_pass
ansible-playbook -i inventory/hosts.yml site.yml --vault-password-file .vault_pass

# Add .vault_pass to .gitignore (already done)
```

## Secrets File Structure

### Database Secrets

```yaml
# PostgreSQL admin password
postgres_admin_password: "strong_random_password"

# Semaphore database credentials
semaphore_db_name: "semaphore"
semaphore_db_user: "semaphore"
semaphore_db_password: "another_strong_password"
```

### Semaphore Application Secrets

```yaml
# Admin user credentials
semaphore_admin_user: "admin"
semaphore_admin_email: "admin@example.com"
semaphore_admin_password: "strong_admin_password"
semaphore_admin_name: "Administrator"

# Encryption keys (MUST be 32 characters minimum)
# Generate with: openssl rand -hex 32
semaphore_cookie_hash: "32_char_hex_string"
semaphore_cookie_encryption: "32_char_hex_string"
semaphore_access_key_encryption: "32_char_hex_string"
```

### TLS Certificate Configuration

```yaml
# Certificate strategy: "generate" or "existing"
tls_cert_strategy: "generate"

# Self-signed certificate settings
tls_cert_lifetime_days: 3650  # 10 years
tls_cert_common_name: "semaphore.local"
tls_cert_organization: "My Organization"

# Or use existing certificates
tls_existing_cert_path: "/path/to/cert.crt"
tls_existing_key_path: "/path/to/key.key"
```

See [TLS-SETUP.md](TLS-SETUP.md) for detailed TLS configuration.

### Network Configuration

```yaml
# Network CIDR for jails
jail_network_cidr: "192.168.1.0/24"
jail_gateway: "192.168.1.1"
jail_interface: "em0"

# Jail IP addresses
jail_ip_database: "192.168.1.50"
jail_ip_semaphore: "192.168.1.51"
jail_ip_nginx: "192.168.1.52"
```

### Backup Configuration

```yaml
backup_dir: "/var/backups/semaphore"
backup_retention_days: 30
backup_encryption_enabled: false
backup_encryption_password: "backup_password"
```

## Ansible Vault Operations

### Encrypt File

```bash
ansible-vault encrypt group_vars/all/secrets.yml
```

### Decrypt File

```bash
ansible-vault decrypt group_vars/all/secrets.yml
```

### Edit Encrypted File

```bash
# Best way - edits without leaving decrypted file
ansible-vault edit group_vars/all/secrets.yml
```

### View Encrypted File

```bash
ansible-vault view group_vars/all/secrets.yml
```

### Change Vault Password

```bash
ansible-vault rekey group_vars/all/secrets.yml
```

### Encrypt String (for individual values)

```bash
ansible-vault encrypt_string 'mysecretpassword' --name 'semaphore_admin_password'
```

## Using Vault Password File

### Create Password File

```bash
echo "your-strong-vault-password" > .vault_pass
chmod 600 .vault_pass

# Ensure it's in .gitignore (already configured)
```

### Configure ansible.cfg

Already configured in `ansible.cfg`:

```ini
[defaults]
vault_password_file = .vault_pass  # Uncomment this line
```

### Run Playbooks

```bash
# No need for --ask-vault-pass anymore
ansible-playbook -i inventory/hosts.yml site.yml

# Or explicitly specify
ansible-playbook -i inventory/hosts.yml site.yml --vault-password-file .vault_pass
```

## Security Best Practices

### 1. Never Commit Unencrypted Secrets

```bash
# Always check before committing
git status

# If secrets.yml is not encrypted, encrypt it!
ansible-vault encrypt group_vars/all/secrets.yml
```

### 2. Use Strong Passwords

```bash
# Database passwords: 20+ characters
openssl rand -base64 32

# Encryption keys: exactly 32 hex characters
openssl rand -hex 32
```

### 3. Protect Vault Password

```bash
# Store vault password securely
# Options:
# - Password manager (1Password, LastPass, etc.)
# - Environment variable
# - Secure file with restricted permissions

chmod 600 .vault_pass
```

### 4. Rotate Secrets Regularly

Update passwords and keys periodically:

```bash
# Edit secrets
ansible-vault edit group_vars/all/secrets.yml

# Redeploy
ansible-playbook -i inventory/hosts.yml site.yml --ask-vault-pass
```

### 5. Different Environments

Create separate secrets files for different environments:

```
group_vars/
├── all/
│   ├── vars.yml
│   └── secrets.yml
├── production/
│   └── secrets.yml
├── staging/
│   └── secrets.yml
└── development/
    └── secrets.yml
```

## Makefile Integration

Convenient commands for vault operations:

```bash
# Edit vault
make vault-edit

# Create new vault
make vault-create

# Encrypt a file
make vault-encrypt

# Decrypt a file
make vault-decrypt
```

These are already configured in the Makefile.

## Troubleshooting

### ERROR! Attempting to decrypt but no vault secrets found

**Problem:** File is not encrypted, or wrong password

**Solution:**
```bash
# Check if file is encrypted
head group_vars/all/secrets.yml
# Should start with: $ANSIBLE_VAULT;1.1;AES256

# If not encrypted
ansible-vault encrypt group_vars/all/secrets.yml
```

### Vault password is incorrect

**Problem:** Wrong password for encrypted file

**Solution:**
```bash
# If you forgot the password, you'll need to:
# 1. Restore from backup (if you have one)
# 2. Or recreate the file (if first time setup)

# To change password if you remember the old one
ansible-vault rekey group_vars/all/secrets.yml
```

### Deploy fails with "variable not found"

**Problem:** Missing variable in secrets.yml

**Solution:**
```bash
# Check which variable is missing from error message
# Add it to secrets.yml
ansible-vault edit group_vars/all/secrets.yml
```

## Environment-Specific Configuration

### Multiple Environments

**Directory structure:**

```
group_vars/
├── all/
│   ├── vars.yml       # Common non-secret vars
│   └── secrets.yml    # Common secrets
├── production/
│   └── secrets.yml    # Production-specific secrets
└── staging/
    └── secrets.yml    # Staging-specific secrets
```

**inventory/production.yml:**

```yaml
all:
  children:
    jail_hosts:
      hosts:
        prod-bsd:
          ansible_host: 10.0.0.10
```

**inventory/staging.yml:**

```yaml
all:
  children:
    jail_hosts:
      hosts:
        staging-bsd:
          ansible_host: 192.168.1.10
```

**Deploy:**

```bash
# Production
ansible-playbook -i inventory/production.yml site.yml

# Staging
ansible-playbook -i inventory/staging.yml site.yml
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Deploy Semaphore
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Install Ansible
        run: pip install ansible

      - name: Create vault password file
        run: echo "${{ secrets.ANSIBLE_VAULT_PASSWORD }}" > .vault_pass

      - name: Deploy
        run: ansible-playbook -i inventory/hosts.yml site.yml
```

Store `ANSIBLE_VAULT_PASSWORD` in GitHub Secrets.

### GitLab CI Example

```yaml
deploy:
  stage: deploy
  script:
    - echo "$ANSIBLE_VAULT_PASSWORD" > .vault_pass
    - ansible-playbook -i inventory/hosts.yml site.yml
  only:
    - main
```

## Template for New Deployments

**Example `secrets.yml` for new deployment:**

```yaml
---
# REPLACE ALL VALUES BELOW WITH YOUR OWN

# Database
postgres_admin_password: "$(openssl rand -base64 32)"
semaphore_db_name: "semaphore"
semaphore_db_user: "semaphore"
semaphore_db_password: "$(openssl rand -base64 32)"

# Semaphore Admin
semaphore_admin_user: "admin"
semaphore_admin_email: "your-email@example.com"
semaphore_admin_password: "$(openssl rand -base64 24)"
semaphore_admin_name: "Administrator"

# Encryption Keys
semaphore_cookie_hash: "$(openssl rand -hex 32)"
semaphore_cookie_encryption: "$(openssl rand -hex 32)"
semaphore_access_key_encryption: "$(openssl rand -hex 32)"

# TLS
tls_cert_strategy: "generate"
tls_cert_lifetime_days: 3650
tls_cert_common_name: "semaphore.yourdomain.com"

# Network (update with your IPs)
jail_network_cidr: "192.168.1.0/24"
jail_gateway: "192.168.1.1"
jail_interface: "em0"
jail_ip_database: "192.168.1.50"
jail_ip_semaphore: "192.168.1.51"
jail_ip_nginx: "192.168.1.52"
```

**Quick setup:**

```bash
# Copy template
cp group_vars/all/secrets.yml group_vars/all/secrets.yml.example

# Edit with your values
vim group_vars/all/secrets.yml

# Encrypt
ansible-vault encrypt group_vars/all/secrets.yml

# Deploy
ansible-playbook -i inventory/hosts.yml site.yml --ask-vault-pass
```

## References

- [Ansible Vault Documentation](https://docs.ansible.com/ansible/latest/user_guide/vault.html)
- [Password Security Best Practices](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
