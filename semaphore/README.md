# Ansible Semaphore on BSD Jails

Infrastructure as Code deployment for [Ansible Semaphore](https://www.ansible-semaphore.com/) on FreeBSD jails using native jail tools and Ansible.

## Overview

This project provides a complete, production-ready IaC solution for deploying Ansible Semaphore in isolated FreeBSD jails with:

- **Multi-jail architecture**: Separate jails for application and database
- **Native BSD tools**: Uses jail.conf, ZFS, and pf - no external jail managers
- **Automated deployment**: Full lifecycle management (deploy, update, backup, destroy)
- **Security**: Isolated environments with proper firewall configuration
- **Scalability**: ZFS-backed storage with snapshot/clone capabilities

## Architecture

```
┌─────────────────────────────────────────────────────┐
│  FreeBSD Host (jail_hosts)                          │
│                                                      │
│  ┌────────────────┐    ┌─────────────────────┐     │
│  │ Database       │    │ Application         │     │
│  │                │    │                     │     │
│  │ semaphore-db   │◄───┤ semaphore-app       │     │
│  │ 192.168.1.50   │    │ 192.168.1.51:3000   │◄────┼── Internet (HTTPS)
│  │                │    │                     │     │
│  │ PostgreSQL 15  │    │ Semaphore + Native  │     │
│  │ Port: 5432     │    │ TLS/HTTPS Support   │     │
│  └────────────────┘    └─────────────────────┘     │
│                                                      │
│  🔒 Security: Native TLS, isolated jails            │
│  💾 Storage: ZFS (zroot/jails/*)                    │
│  🌐 Network: NAT via pf                             │
└─────────────────────────────────────────────────────┘
```

## Prerequisites

### FreeBSD Host Requirements

- FreeBSD 13.0 or higher
- ZFS filesystem
- Root access
- Network connectivity
- Minimum 4GB RAM, 20GB storage

### Control Machine Requirements

- Ansible 2.10+
- Python 3.8+
- SSH access to FreeBSD host
- Required Ansible collections (install with `make requirements`):
  - community.general
  - community.postgresql

## Quick Start

### 1. Clone and Configure

```bash
git clone <your-repo>
cd semaphore-ansible

# Install requirements
make requirements

# Generate secure secrets (recommended for new deployments)
./scripts/generate-secrets.sh

# Configure secrets (ALL CONFIGURATION IN ONE FILE!)
# Copy the generated secrets from the script output above
vim group_vars/all/secrets.yml  # Update passwords, IPs, TLS settings

# Update inventory with your BSD host IP
vim inventory/hosts.yml
```

**Important:** All secrets and configuration are centralized in `group_vars/all/secrets.yml`:
- Database passwords
- Admin credentials
- TLS certificate settings
- Network configuration
- Everything in one place!

See [docs/SECRETS-MANAGEMENT.md](docs/SECRETS-MANAGEMENT.md) for details.

### 2. Configure Inventory

Edit `inventory/hosts.yml`:

```yaml
jail_hosts:
  hosts:
    bsd-host:
      ansible_host: YOUR_BSD_HOST_IP  # Change this
      ansible_user: root
```

### 3. Test Connectivity

```bash
make check
```

### 4. Deploy Everything

```bash
make deploy
```

This will:
1. Prepare the BSD host (ZFS, networking, base system)
2. Create and configure the database jail
3. Create and configure the Semaphore jail
4. Verify the deployment

### 5. Access Semaphore

After deployment completes:

```
URL: https://192.168.1.51:3000  (HTTPS - secure!)
Username: admin
Password: (from secrets.yml)
```

**🔒 Security Notes:**
- Semaphore serves HTTPS natively (TLS built-in)
- Self-signed certificate by default (browser warning is normal)
- Click "Advanced" → "Proceed" to accept certificate
- Change default password immediately!

**⚠️ IMPORTANT:** Certificates are auto-generated if they don't exist, or you can bring your own!

## Usage

### Common Operations

```bash
# Full deployment
make deploy

# Update Semaphore version
make update

# Backup everything
make backup

# Check status
make status

# Verify deployment
make verify

# View logs
make logs-app
make logs-db

# Access jail shells
make shell-app
make shell-db

# Destroy everything (careful!)
make destroy
```

### Manual Ansible Commands

```bash
# Deploy with verbose output
ansible-playbook -i inventory/hosts.yml site.yml -vv

# Deploy only database
ansible-playbook -i inventory/hosts.yml playbooks/02-deploy-database.yml

# Run with tags
ansible-playbook -i inventory/hosts.yml site.yml --tags database

# Check mode (dry-run)
ansible-playbook -i inventory/hosts.yml site.yml --check
```

## Configuration

### 🔐 Centralized Secrets (NEW!)

**All configuration is centralized in ONE file:** `group_vars/all/secrets.yml`

```yaml
# Edit this file for ALL configuration:
vim group_vars/all/secrets.yml

# Includes:
# - Database passwords
# - Admin credentials
# - TLS/certificate settings
# - Network configuration
# - Everything!
```

**Key settings to update:**

| Setting | Location | Description |
|---------|----------|-------------|
| Database password | `semaphore_db_password` | PostgreSQL password |
| Admin password | `semaphore_admin_password` | Semaphore admin password |
| Encryption keys | `semaphore_cookie_*` | Generate with helper script (see below) |
| Jail IPs | `jail_ip_*` | IP addresses for jails |
| TLS strategy | `tls_cert_strategy` | "generate" or "existing" |
| Certificate lifetime | `tls_cert_lifetime_days` | Days until cert expires (default: 3650) |

### 🔑 Secrets Generator Helper

Use the built-in helper script to generate all required secrets:

```bash
./scripts/generate-secrets.sh
```

**What it generates:**
- ✅ Database passwords (base64-encoded, 32 bytes)
- ✅ Admin password (base64-encoded, 32 bytes)
- ✅ Cookie hash (base64-encoded, 32 bytes)
- ✅ Cookie encryption key (base64-encoded, 32 bytes)
- ✅ Access key encryption (base64-encoded, 32 bytes)

**Example output:**
```yaml
# Database Secrets
postgres_admin_password: "0lxyMMOUbVxlVdQziFt/qBLjr6n81I7WThy2j/NDZFw="
semaphore_db_password: "tZqczI2Q7ZPUrngsLdLyQpA35MqEQnNerhp7dn54WuE="

# Semaphore Admin Credentials
semaphore_admin_password: "rW0qxc9wUEWWwziW4P2bsz3jyRqbh+M9F3+Z0QaUTSE="

# Semaphore Encryption Keys
semaphore_cookie_hash: "AOFCPe+yo1izsXA0HGXJ/oA4Evr+oyVLKhZIdnbTFSY="
semaphore_cookie_encryption: "6HBb78X8cLfghIkeGDrn8R3QJtRPRz40BtEFzmYajj0="
semaphore_access_key_encryption: "20llMOxE8jw5vvhtGrIgCG6QteQ+3vo5Q2wfPMRFtUQ="
```

**⚠️ Important:**
- Keys MUST be base64-encoded (not hex!)
- Each key should be exactly 32 bytes before encoding
- Use `openssl rand -base64 32` to generate individual keys

Copy the output to `group_vars/all/secrets.yml` and customize the admin username/email as needed.

### 🔒 Secrets Management with Ansible Vault

**Encrypt your secrets before committing:**

```bash
# Encrypt secrets file
ansible-vault encrypt group_vars/all/secrets.yml

# Edit encrypted file
ansible-vault edit group_vars/all/secrets.yml

# Deploy with vault
ansible-playbook -i inventory/hosts.yml site.yml --ask-vault-pass
```

See [docs/SECRETS-MANAGEMENT.md](docs/SECRETS-MANAGEMENT.md) for complete guide.

### 🔐 TLS/HTTPS Configuration

**Two options for TLS certificates:**

1. **Self-signed (default)** - Auto-generated during deployment
2. **Existing certificates** - Bring your own (Let's Encrypt, etc.)

```yaml
# In group_vars/all/secrets.yml:

# Option 1: Self-signed (automatic)
tls_cert_strategy: "generate"
tls_cert_lifetime_days: 3650  # 10 years

# Option 2: Use existing certificates
tls_cert_strategy: "existing"
tls_existing_cert_path: "/path/to/cert.crt"
tls_existing_key_path: "/path/to/key.key"
```

Certificates are automatically:
- Generated if they don't exist
- Reused if they already exist
- Backed up with `make backup`

See [docs/TLS-SETUP.md](docs/TLS-SETUP.md) for complete TLS guide.

### Group Variables

- `group_vars/all/secrets.yml` - **ALL configuration and secrets**
- `group_vars/all/vars.yml` - Non-sensitive defaults
- `group_vars/jail_hosts.yml` - Host-specific settings
- `group_vars/all_jails.yml` - Jail defaults

## Project Structure

```
semaphore-ansible/
├── ansible.cfg              # Ansible configuration
├── site.yml                 # Main playbook
├── Makefile                 # Convenience commands
├── inventory/
│   └── hosts.yml           # Inventory definition
├── playbooks/
│   ├── 01-prepare-host.yml # Prepare BSD host
│   ├── 02-deploy-database.yml
│   ├── 03-deploy-semaphore.yml
│   ├── 04-verify-deployment.yml
│   ├── update-semaphore.yml
│   ├── backup.yml
│   └── destroy.yml
├── roles/
│   ├── jail-base/          # Base jail creation
│   ├── postgresql/         # Database setup
│   └── semaphore/          # Semaphore installation
└── group_vars/
    ├── all.yml
    ├── jail_hosts.yml
    └── all_jails.yml
```

## Operations Guide

### Updating Semaphore

```bash
# Interactive update
make update

# Or specify version
ansible-playbook -i inventory/hosts.yml playbooks/update-semaphore.yml \
  -e "semaphore_new_version=v2.10.0"
```

### Backup and Restore

**Backup:**
```bash
make backup
```

Creates:
- ZFS snapshots of jails
- PostgreSQL dump
- Configuration backup

**Restore from snapshot:**
```bash
# List snapshots
zfs list -t snapshot

# Rollback to snapshot
zfs rollback zroot/jails/data/db@backup-TIMESTAMP
zfs rollback zroot/jails/data/semaphore@backup-TIMESTAMP

# Restart jails
service jail restart
```

### Monitoring

```bash
# Check jail status
jls -v

# Check Semaphore status
jexec semaphore-app service semaphore status

# Check database status
jexec semaphore-db service postgresql status

# View processes
jexec semaphore-app top
```

### Troubleshooting

**Jails won't start:**
```bash
# Check jail configuration
jail -f /etc/jail.conf -c test

# Check logs
tail -f /var/log/messages
```

**Semaphore can't connect to database:**
```bash
# Test from app jail
jexec semaphore-app nc -zv 192.168.1.50 5432

# Check PostgreSQL is listening
jexec semaphore-db sockstat -l | grep 5432

# Check pg_hba.conf allows connections
jexec semaphore-db cat /var/db/postgres/data15/pg_hba.conf
```

**Network issues:**
```bash
# Check pf rules
pfctl -sr

# Test connectivity
jexec semaphore-app ping 192.168.1.1
```

## Security Considerations

1. **Change default passwords** in inventory before deployment
2. **Use Ansible Vault** for sensitive variables
3. **Configure firewall** on BSD host to restrict access
4. **Regular backups** - automate with cron
5. **Keep updated** - Semaphore and FreeBSD patches
6. **SSL/TLS** - Use reverse proxy (nginx) for HTTPS
7. **Jail hardening** - Review jail security parameters

## Advanced Configuration

### Using VNET (isolated network stack)

Edit `inventory/hosts.yml`:
```yaml
semaphore-app:
  jail_vnet: true
```

### Custom ZFS pool

Edit `group_vars/all.yml`:
```yaml
zfs_pool: tank
jail_dataset: containers
```

### Multiple Semaphore instances

Copy and modify jail definitions in inventory for additional instances.

## Contributing

Contributions welcome! Please:
1. Test changes on FreeBSD 13.2+
2. Follow Ansible best practices
3. Update documentation
4. Submit pull requests

## License

MIT License - See LICENSE file

## Documentation

📚 **Comprehensive guides available:**

- **[README.md](README.md)** - This file, main overview
- **[docs/QUICKSTART.md](docs/QUICKSTART.md)** - Get running in 5 minutes
- **[docs/SECRETS-MANAGEMENT.md](docs/SECRETS-MANAGEMENT.md)** - Centralized secrets & Ansible Vault
- **[docs/TLS-SETUP.md](docs/TLS-SETUP.md)** - HTTPS/TLS certificate management
- **[docs/CA-CERTIFICATES.md](docs/CA-CERTIFICATES.md)** - Custom CA import (for LDAPS, etc.)
- **[docs/BACKUP-RESTORE.md](docs/BACKUP-RESTORE.md)** - Data backup & restore (IaC approach)
- **[docs/OPERATIONS.md](docs/OPERATIONS.md)** - Day-to-day operations
- **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** - Technical deep dive

## Key Features

✅ **Centralized Configuration** - All settings in `group_vars/all/secrets.yml`
✅ **HTTPS/TLS by Default** - Semaphore native TLS support
✅ **Certificate Management** - Auto-generation, configurable lifetime, reuse existing
✅ **Custom CA Import** - Support for LDAPS with self-signed CAs
✅ **Data-Only Backups** - IaC approach (backup data, not infrastructure)
✅ **Ansible Vault Support** - Encrypt your secrets
✅ **Two-Jail Architecture** - Database and Application (simple & clean)
✅ **Native BSD Jails** - No external tools required
✅ **Production Ready** - Battle-tested configuration

## Resources

- [Ansible Semaphore Docs](https://docs.ansible-semaphore.com/)
- [FreeBSD Jails Handbook](https://docs.freebsd.org/en/books/handbook/jails/)
- [Ansible Documentation](https://docs.ansible.com/)
- [Ansible Vault Guide](https://docs.ansible.com/ansible/latest/user_guide/vault.html)
- [Nginx SSL Module](https://nginx.org/en/docs/http/ngx_http_ssl_module.html)

## Support

- Issues: Open a GitHub issue
- FreeBSD Jails: FreeBSD forums/mailing lists
- Semaphore: Semaphore GitHub discussions

---

**Built with ❤️ for the BSD community**

🔒 **Security First** | 📦 **All-in-One Configuration** | 🚀 **Production Ready**
