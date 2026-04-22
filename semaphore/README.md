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
git clone https://github.com/gabrielbelli/jail-forge.git
cd jail-forge

# Install Ansible and required collections
make requirements

# Configure and deploy Semaphore
cd semaphore

# Generate secure secrets (recommended for new deployments)
./scripts/generate-secrets.sh

# Configure your deployment
vim group_vars/all/vars.yml     # Network, TLS metadata, versions, backup settings
vim group_vars/all/secrets.yml  # Passwords and encryption keys (generated above)

# Update inventory with your BSD host IP
vim inventory/hosts.yml
```

**Important:** Configuration is split between two files:
- `group_vars/all/vars.yml` — non-sensitive settings (network, TLS metadata, versions, backup)
- `group_vars/all/secrets.yml` — passwords and encryption keys

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

Configuration is split into two files:

```yaml
# Non-sensitive settings (network, TLS metadata, versions, backup):
vim group_vars/all/vars.yml

# Passwords and encryption keys:
vim group_vars/all/secrets.yml
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

The script writes directly to `group_vars/all/secrets.yml`. Review and customise the admin username/email as needed.

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

### 🔐 TLS/HTTPS Configuration

**Two options for TLS certificates:**

1. **Self-signed (default)** - Auto-generated during deployment
2. **Existing certificates** - Bring your own (Let's Encrypt, etc.)

```yaml
# In group_vars/all/vars.yml:

# Option 1: Self-signed (automatic)
tls_cert_strategy: "generate"
tls_cert_lifetime_days: 3650  # 10 years

# Option 2: Use existing certificates (set paths in vars.yml)
tls_cert_strategy: "existing"
```

Certificates are automatically:
- Generated if they don't exist
- Reused if they already exist
- Backed up with `make backup`

### 🌐 Network Configuration

**Four network modes available:**

1. **Alias mode** - Jails use IP aliases on host interface (simplest)
2. **NAT mode** - Jails on private network with pf NAT (port forwarding)
3. **VNET mode** - Jails with isolated network stack (most advanced)
4. **Inherit mode** - Jails share parent's network (for nested jail deployments)

```yaml
# In group_vars/all/vars.yml:

# Option 1: Alias mode (default) - jails on same subnet as host
jail_network_mode: "alias"
jail_interface: "em0"
jail_network_cidr: "192.168.1.0/24"
jail_gateway: "192.168.1.1"
jail_ip_database: "192.168.1.50"
jail_ip_semaphore: "192.168.1.51"

# Option 2: NAT mode - jails on private network with port forwarding
jail_network_mode: "nat"
jail_interface: "em0"
jail_nat_interface: "lo1"
jail_network_cidr: "10.0.0.0/24"
jail_ip_database: "10.0.0.50"
jail_ip_semaphore: "10.0.0.51"
semaphore_port: 3000  # Forwarded to host

# Option 3: VNET mode - isolated network stack (advanced)
jail_network_mode: "vnet"
jail_interface: "em0"
jail_bridge_interface: "bridge0"  # Optional, defaults to bridge0
jail_network_cidr: "10.0.0.0/24"
jail_ip_database: "10.0.0.50"
jail_ip_semaphore: "10.0.0.51"

# Option 4: Inherit mode - nested jails (inside another jail)
jail_network_mode: "inherit"
jail_ip_database: "127.0.0.1"    # Services communicate via localhost
jail_ip_semaphore: "127.0.0.1"
```

**When to use each mode:**

| Mode | Use Case | Pros | Cons |
|------|----------|------|------|
| **Alias** | Simple deployments, same subnet | Easy setup, direct access | Requires routable IPs |
| **NAT** | Private network, port forwarding | IP isolation, any subnet | Requires pf configuration |
| **VNET** | Maximum isolation, per-jail firewall | Full network stack isolation | More complex, requires bridge |
| **Inherit** | Nested jails (jail inside a jail) | No host access needed, no pf | No network isolation between jails |

**VNET Requirements:**
- FreeBSD with VNET support (13.0+)
- Bridge interface (auto-created)
- Per-jail network configuration
- Advanced firewall capabilities

**Inherit Mode Requirements (nested jails):**
- Parent jail with `children.max` set by host admin
- `allow.mount`, `allow.mount.zfs`, `allow.mount.devfs`, `allow.mount.nullfs`
- Delegated ZFS dataset (`jailed=on`)

See the Advanced Configuration section below for additional VNET details.

### Group Variables

- `group_vars/all/vars.yml` - Non-sensitive configuration (network, TLS metadata, versions, backup)
- `group_vars/all/secrets.yml` - Passwords and encryption keys
- `group_vars/all_jails.yml` - Jail defaults

## Project Structure

```
semaphore/
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
    ├── all/
    │   ├── vars.yml
    │   └── secrets.yml
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
6. **SSL/TLS** - Use native TLS support or a reverse proxy for HTTPS
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
1. Test changes on FreeBSD 13.0+
2. Follow Ansible best practices
3. Update documentation
4. Submit pull requests

## License

BSD 2-Clause License - See LICENSE file

## Documentation

- **[README.md](README.md)** - This file, deployment and operations guide
- **[Project README](../README.md)** - jail-forge overview, design principles, network modes
- **[CONTRIBUTING.md](../CONTRIBUTING.md)** - Guidelines for adding new applications
- **[TESTING.md](../.github/TESTING.md)** - CI/CD setup and workflow configuration

## Key Features

✅ **Centralized Configuration** - Settings in `group_vars/all/vars.yml` and `secrets.yml`
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


## Support

- Issues: Open a GitHub issue
- FreeBSD Jails: FreeBSD forums/mailing lists
- Semaphore: Semaphore GitHub discussions

---

**Built with ❤️ for the BSD community**

🔒 **Security First** | 📦 **All-in-One Configuration** | 🚀 **Production Ready**
