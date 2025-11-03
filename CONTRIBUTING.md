# Contributing to jail-forge

Thank you for considering contributing to jail-forge! This document provides guidelines for contributing new application deployments, improvements, and bug fixes.

## How to Contribute

### Reporting Bugs

If you find a bug in an existing deployment:

1. Check if the issue already exists in the issue tracker
2. If not, create a new issue with:
   - Clear description of the problem
   - Steps to reproduce
   - Expected vs actual behavior
   - FreeBSD version and environment details
   - Relevant logs or error messages

### Suggesting Enhancements

For feature requests or enhancements:

1. Open an issue describing the enhancement
2. Explain the use case and benefits
3. Discuss the proposed implementation if you have ideas

### Contributing Code

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-new-app`)
3. Make your changes following the guidelines below
4. Test thoroughly
5. Commit with clear, descriptive messages
6. Push to your fork
7. Submit a pull request

## Adding a New Application

When adding a new application deployment to jail-forge, follow these guidelines:

### 1. Directory Structure

Create a new directory at the root level for your application:

```
jail-forge/
└── your-app/
    ├── README.md              # Application-specific README
    ├── ansible.cfg            # Ansible configuration
    ├── site.yml               # Main orchestrator
    ├── Makefile               # Operational shortcuts
    ├── .env.example           # Environment variables template (if needed)
    ├── TESTING-STATUS.md      # Test results and status
    ├── inventory/
    │   └── hosts.yml.example # Inventory template
    ├── group_vars/
    │   ├── all/
    │   │   ├── vars.yml
    │   │   └── secrets.yml.example
    │   └── jail_hosts.yml
    ├── roles/
    │   ├── database/          # If applicable
    │   └── your-app/
    ├── playbooks/
    │   ├── 01-prepare-host.yml
    │   ├── 02-deploy-database.yml  # If applicable
    │   ├── 03-deploy-app.yml
    │   ├── 04-verify-deployment.yml
    │   ├── backup.yml
    │   ├── restore.yml
    │   ├── disaster-recovery.yml
    │   ├── snapshot.yml
    │   ├── destroy.yml
    │   └── destroy-all.yml
    └── docs/
        ├── ARCHITECTURE.md
        ├── OPERATIONS.md
        └── QUICKSTART.md
```

### 2. Required Components

Every application deployment must include:

#### Essential Playbooks
- **Host preparation**: ZFS setup, jail base system
- **Application deployment**: Complete setup with all dependencies
- **Verification**: Post-deployment checks
- **Backup**: Data-only backup (IaC approach)
- **Restore**: Data restoration procedure
- **Disaster recovery**: Full rebuild from backup
- **Destroy**: Clean removal (preserving data)

#### Documentation
- **README.md**: Quick start guide with clear instructions
- **TESTING-STATUS.md**: Test results on FreeBSD versions
- **Architecture documentation**: How the deployment works
- **Operations guide**: Day-to-day operations

#### Configuration Files
- **ansible.cfg**: Point to both local and shared roles:
  ```ini
  roles_path = roles:../shared/roles
  ```
- **Makefile**: Common operations (deploy, backup, restore, etc.)
- **Templates for sensitive files**: `.example` files for inventory and secrets

### 3. Design Principles to Follow

#### Use Shared Resources
- Use `shared/roles/jail-base` for base jail setup
- Reference `shared/scripts/` for common utilities
- Follow patterns documented in `TEMPLATE-GUIDE.md`

#### Service Management
- Always use `jexec` for service operations in jails:
  ```yaml
  # ✅ Correct
  - name: restart service
    command: jexec {{ jail_name }} service myapp restart

  # ❌ Wrong - runs on host, not in jail
  - name: restart service
    service:
      name: myapp
      state: restarted
  ```

#### Nullfs Mount Cleanup
- If using nullfs mounts, ensure proper cleanup in destroy playbooks:
  ```yaml
  - name: Force unmount nullfs mounts
    shell: |
      mount -t nullfs | grep "myapp" | awk '{print $3}' | xargs -r -n1 umount -f || true
  ```

#### BSD Conventions
- Use `/var/backups/{{ app_name }}` for backups
- Use `/var/log/{{ app_name }}` for logs
- Use `/usr/local/etc/{{ app_name }}` for configs
- Use rc.d scripts for services
- Use newsyslog for log rotation

#### IP Configuration
- Use IP alias mode (not VNET) for simplicity
- Use static IPs for jails
- Document IP requirements in README
- No NAT rules if jails are on same network as host

### 4. Testing Requirements

Before submitting a pull request, test:

1. **Fresh deployment**: On clean FreeBSD system
2. **Backup and restore**: Verify data integrity
3. **Disaster recovery**: Complete rebuild from backup
4. **Destroy and redeploy**: No orphaned resources
5. **Service operations**: Restart, reload, stop, start
6. **Log rotation**: Verify logs rotate properly

Document test results in `TESTING-STATUS.md`:
```markdown
# Testing Status

## Environment
- FreeBSD Version: 13.5-RELEASE
- ZFS Version: 2.1
- Ansible Version: 2.15.0
- Test Date: 2025-11-03

## Test Results

- [x] Fresh deployment
- [x] Backup and restore
- [x] Disaster recovery
- [x] Destroy and redeploy
- [x] Service operations
- [x] Log rotation

## Known Issues
None
```

### 5. Documentation Standards

#### README.md Structure
```markdown
# Application Name

Brief description

## Features
- List key features

## Requirements
- FreeBSD version
- Dependencies
- Network requirements

## Quick Start
1. Step-by-step instructions
2. Configuration
3. Deployment

## Architecture
Link to detailed architecture docs

## Operations
Link to operations guide

## Troubleshooting
Common issues and solutions
```

#### Code Comments
- Comment complex logic
- Explain non-obvious decisions
- Document workarounds with context
- Use YAML comments in playbooks

### 6. Commit Messages

Follow conventional commit format:

```
type(scope): brief description

Detailed explanation of changes if needed

- Bullet points for specific changes
- References to related issues
```

Types:
- `feat`: New feature or application
- `fix`: Bug fix
- `docs`: Documentation changes
- `refactor`: Code restructuring
- `test`: Testing changes
- `chore`: Maintenance tasks

Examples:
```
feat(nextcloud): Add Nextcloud deployment with PostgreSQL

Complete Nextcloud deployment with:
- PostgreSQL 15 in dedicated jail
- Redis for caching
- Nginx reverse proxy
- TLS support
- Backup/restore playbooks

Tested on FreeBSD 13.5-RELEASE
```

```
fix(semaphore): Correct nullfs mount cleanup in destroy

- Add service shutdown before jail stop
- Force unmount orphaned nullfs mounts
- Remove fstab files

Fixes #123
```

### 7. Code Review Process

Pull requests will be reviewed for:

- [ ] Follows directory structure guidelines
- [ ] Includes all required playbooks
- [ ] Properly uses shared resources
- [ ] Follows BSD conventions
- [ ] Includes comprehensive documentation
- [ ] Has been tested on FreeBSD
- [ ] Uses proper service management (jexec)
- [ ] Handles nullfs mounts correctly
- [ ] Clear commit messages
- [ ] No sensitive data in code

## Style Guidelines

### YAML
- Use 2 spaces for indentation
- Quote strings when needed for clarity
- Use descriptive task names
- Group related tasks with comments

### Jinja2 Templates
- Use descriptive variable names
- Comment complex logic
- Maintain consistent formatting

### Shell Scripts
- Use shellcheck-compliant syntax
- Include error handling
- Add descriptive comments

## Questions or Help?

- Open an issue for questions
- Tag with `question` label
- Reference `TEMPLATE-GUIDE.md` for patterns

## License

By contributing to jail-forge, you agree that your contributions will be licensed under the BSD 2-Clause License.
