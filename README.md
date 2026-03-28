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
├── README.md                 # This file
├── CONTRIBUTING.md           # How to contribute
├── LICENSE                   # BSD 2-Clause License
├── .github/workflows/        # CI/CD testing
├── shared/roles/jail-base/   # Base jail role (reusable)
├── semaphore/                # Semaphore deployment
│   ├── README.md
│   ├── Makefile
│   ├── playbooks/
│   ├── inventory/
│   └── group_vars/
└── <your-app>/               # Your application here
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

## Adding New Applications

Adding a new application follows this pattern:

### 1. Create Application Directory
```bash
mkdir -p myapp/{playbooks,inventory,group_vars/all,roles,scripts}
```

### 2. Copy Configuration Templates
```bash
# From an existing app like semaphore
cp -r semaphore/inventory/hosts.yml.example myapp/inventory/
cp -r semaphore/group_vars/all/secrets.yml.template myapp/group_vars/all/
cp semaphore/{ansible.cfg,Makefile} myapp/
```

### 3. Create Core Playbooks

Each app needs these playbooks in `playbooks/`:
- `prepare-host.yml` - Create ZFS datasets, install jail-forge
- `deploy-db.yml` - Setup database jail (PostgreSQL/MySQL/etc)
- `deploy-app.yml` - Setup application jail and software
- `backup.yml` - Backup data directories
- `restore.yml` - Restore from backup
- `destroy-all.yml` - Clean teardown

Use semaphore as a reference implementation.

### 4. Update GitHub Actions

Add your app to `.github/workflows/test-lifecycle.yml`:
```yaml
APPS_JSON: |
  [
    { "name": "semaphore", ... },
    {
      "name": "myapp",
      "working_dir": "myapp",
      "jail_name": "myapp-app",
      "port": 8080,
      "health_endpoint": "/health",
      "service_name": "myapp",
      "backup_location": "/var/backups/myapp"
    }
  ]
```

### 5. Test Lifecycle
```bash
cd myapp
make deploy    # Deploy full stack
make backup    # Test backup
make restore   # Test restore
```

That's it. Keep it simple.


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

GitHub Actions tests the full lifecycle automatically. See [.github/TESTING.md](.github/TESTING.md) for CI/CD setup.

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
