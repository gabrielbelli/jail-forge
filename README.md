# jail-forge

**Production-ready FreeBSD jail deployments with Ansible**

jail-forge is a curated collection of battle-tested deployment configurations for self-hosted applications on FreeBSD using jails and Ansible. Each application is fully configured with deployment automation, backup/restore capabilities, and disaster recovery procedures.

## Features

- **Infrastructure as Code**: Complete infrastructure reproducible from code
- **Service Isolation**: Each service runs in its own FreeBSD jail
- **Production Ready**: Tested deployment patterns with proper error handling
- **Complete Lifecycle**: Deploy, backup, restore, snapshot, and destroy operations
- **BSD Conventions**: Follows FreeBSD standards for paths and services
- **Shared Resources**: Reusable roles and patterns across all applications

## Available Applications

### [Semaphore](./semaphore/)
Ansible automation and deployment platform with PostgreSQL backend.

- **Status**: ✅ Production Ready
- **Services**: Semaphore 2.16.37, PostgreSQL 15
- **Jails**: 2 (app + database)
- **Features**: TLS support, custom CA import, backup/restore, disaster recovery

## Repository Structure

```
jail-forge/
├── LICENSE                   # BSD 2-Clause License
├── README.md                 # This file
├── TEMPLATE-GUIDE.md         # Comprehensive guide for creating new deployments
│
├── shared/                   # Shared resources across all applications
│   ├── roles/
│   │   └── jail-base/       # Base jail configuration (ZFS, networking)
│   ├── scripts/
│   │   └── generate-secrets.sh  # Secret generation utility
│   └── docs/
│       ├── JAIL-NETWORKING.md   # Networking patterns
│       ├── BACKUP-STRATEGIES.md # Backup approaches
│       └── SECURITY.md          # Security best practices
│
├── semaphore/                # Ansible Semaphore deployment
│   ├── README.md
│   ├── ansible.cfg
│   ├── site.yml
│   ├── Makefile
│   ├── inventory/
│   ├── group_vars/
│   ├── roles/
│   ├── playbooks/
│   └── docs/
│
└── <future-apps>/            # More applications coming soon!
```

## Quick Start

### 1. Choose an Application

Browse the available applications above and cd into its directory:

```bash
cd semaphore/
```

### 2. Configure Deployment

Each application has its own configuration. See the application's README for specific setup instructions.

```bash
# Copy example configuration files
cp inventory/hosts.yml.example inventory/hosts.yml
cp group_vars/all/secrets.yml.example group_vars/all/secrets.yml

# Edit with your values
vim inventory/hosts.yml
vim group_vars/all/secrets.yml
```

### 3. Deploy

```bash
# Check connectivity
make check

# Deploy full stack
make deploy
```

## Key Design Principles

### Infrastructure as Code (IaC)
All infrastructure is defined in code and can be rebuilt from scratch at any time. Backups contain only data, not configuration.

### Service Isolation
Each service runs in its own FreeBSD jail for security and maintainability. Multi-tier applications use separate jails (e.g., database jail + app jail).

### IP Alias Mode
Static IP addresses for stability and simplicity. No VNET complexity - jails use IP aliases on the host's network interface.

### BSD Conventions
- Paths: `/var/backups`, `/var/log`, `/usr/local/etc`
- Services: rc.d scripts, newsyslog for log rotation
- Networking: Static IPs, PF for firewall (optional)

### Complete Lifecycle
Every deployment includes:
- ✅ Automated deployment
- ✅ Backup with retention policies
- ✅ Restore procedures
- ✅ ZFS snapshots for quick rollback
- ✅ Disaster recovery (full rebuild + restore)
- ✅ Clean destroy operations

## Creating New Deployments

Want to add a new application? See the comprehensive [TEMPLATE-GUIDE.md](./TEMPLATE-GUIDE.md) which documents all the patterns and best practices established in this project.

The template guide covers:
- Project structure and organization
- Key design patterns (jexec for service management, nullfs cleanup, etc.)
- Complete playbook examples
- Common pitfalls and solutions
- Testing and validation procedures

## Shared Resources

### Roles

#### `jail-base`
Base jail configuration used by all applications:
- ZFS dataset creation
- Jail configuration files
- Network setup
- Nullfs mounts
- Basic jail lifecycle

### Scripts

#### `generate-secrets.sh`
Generates secure random secrets for application deployment.

```bash
../shared/scripts/generate-secrets.sh
```

### Documentation

- **JAIL-NETWORKING.md**: IP alias vs VNET, static vs DHCP, networking patterns
- **BACKUP-STRATEGIES.md**: Time-based vs count-based retention, ZFS snapshots, encryption
- **SECURITY.md**: PF configuration, TLS setup, secret management, jail hardening

## Requirements

- **OS**: FreeBSD 13.0+ (tested on 13.5-RELEASE)
- **Filesystem**: ZFS
- **Software**: Ansible 2.9+, Python 3.9+
- **Network**: Available IP addresses for jail assignment

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](./CONTRIBUTING.md) for guidelines on:
- Adding new applications
- Improving existing deployments
- Documentation improvements
- Bug fixes and enhancements

## Community Applications

The following applications are planned or in development:

- [ ] **Nextcloud** - Self-hosted file sync and sharing
- [ ] **Gitea** - Lightweight Git server
- [ ] **Authentik** - Identity provider (SSO)
- [ ] **Miniflux** - Minimalist RSS reader
- [ ] **Vaultwarden** - Bitwarden-compatible password manager
- [ ] **MinIO** - Object storage server
- [ ] **Traefik** - Reverse proxy and load balancer

Want to contribute a deployment? Fork the repo and submit a PR!

## Testing

All deployments in this repository are tested on:
- FreeBSD 13.5-RELEASE
- ZFS filesystem
- Ansible 2.15+
- Production-like scenarios (deploy, backup, restore, disaster recovery)

Each application directory contains a `TESTING-STATUS.md` documenting test results.

## Documentation

Each application has its own detailed documentation:
- `<app>/README.md` - Quick start and overview
- `<app>/docs/` - Detailed documentation for that application

Root-level documentation:
- [TEMPLATE-GUIDE.md](./TEMPLATE-GUIDE.md) - Creating new deployments
- [LICENSE](./LICENSE) - BSD 2-Clause License

## License

jail-forge is licensed under the BSD 2-Clause License. See [LICENSE](./LICENSE) for details.

Individual applications deployed by jail-forge retain their own licenses.

## Author

Gabriel Belli

## Support

- **Issues**: Open an issue on the repository
- **Discussions**: For questions and community discussion

## Acknowledgments

This project builds upon:
- The excellent FreeBSD jails system
- The Ansible automation platform
- The BSD community's commitment to quality and simplicity

## Star History

If you find jail-forge useful, please consider starring the repository!
