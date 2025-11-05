# Jail-Forge Architecture

This document describes the architectural design, philosophy, and technical decisions behind jail-forge.

## Table of Contents

- [Design Philosophy](#design-philosophy)
- [System Overview](#system-overview)
- [Directory Structure](#directory-structure)
- [Jail Architecture](#jail-architecture)
- [Data Management](#data-management)
- [Network Configuration](#network-configuration)
- [Execution Flow](#execution-flow)

---

## Design Philosophy

### Infrastructure as Code (IaC)

Jail-forge treats infrastructure as disposable and reproducible:

- **Jails are ephemeral** - Can be destroyed and recreated at any time
- **Data is persistent** - Stored separately from jails in ZFS datasets
- **Configuration is versioned** - All setup defined in Ansible playbooks
- **Secrets are templated** - Sensitive data injected at runtime

### Data-Only Backups

Unlike traditional VM backups, jail-forge backs up **data only**:

- ✅ Application data (databases, files, configurations)
- ✅ User-generated content
- ❌ Operating system files
- ❌ Installed packages
- ❌ Jail filesystem

**Why?** Jails can be rebuilt from playbooks in minutes. Backing up the entire jail is redundant and wasteful.

### Separation of Concerns

Each application gets **two jails**:

1. **Database jail** - PostgreSQL/MySQL/etc (stateful)
2. **Application jail** - Web app, services (mostly stateless)

**Benefits:**
- Independent scaling and maintenance
- Database can be shared across apps
- Easier troubleshooting and monitoring
- Clean disaster recovery

---

## System Overview

```
┌─────────────────────────────────────────────────────────────┐
│                      FreeBSD Host                            │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                  jail-forge                            │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌─────────────┐ │  │
│  │  │ semaphore-db │  │semaphore-app │  │ nextcloud...│ │  │
│  │  │ PostgreSQL   │  │  Semaphore   │  │             │ │  │
│  │  │ 192.168.1.50 │  │ 192.168.1.51 │  │ 192.168.1.x │ │  │
│  │  └──────────────┘  └──────────────┘  └─────────────┘ │  │
│  │         │                  │                           │  │
│  │         └──────────────────┴───────────────────────────┤  │
│  │                   ZFS Datasets                         │  │
│  │         /zroot/jails/data/semaphore/{db,app}          │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### Components

- **Host System**: FreeBSD 13.x+ with ZFS
- **Jail Management**: jail-forge (rc.conf.d based)
- **Configuration**: Ansible playbooks
- **CI/CD**: GitHub Actions with self-hosted runner
- **Backups**: Data directories + database dumps

---

## Directory Structure

```
jail-forge/                     # Monorepo root
├── .github/
│   ├── workflows/
│   │   └── test-lifecycle.yml  # Multi-app CI/CD workflow
│   └── TESTING.md              # Workflow documentation
│
├── semaphore/                  # Application directory (template)
│   ├── playbooks/
│   │   ├── site.yml            # Main orchestrator (runs all below)
│   │   ├── prepare-host.yml    # ZFS datasets, jail-forge setup
│   │   ├── deploy-db.yml       # Database jail + PostgreSQL
│   │   ├── deploy-app.yml      # Application jail + software
│   │   ├── backup.yml          # Create backup (data only)
│   │   ├── restore.yml         # Restore from backup
│   │   ├── snapshot.yml        # ZFS snapshots
│   │   ├── destroy-all.yml     # Complete teardown
│   │   └── disaster-recovery.yml # Rebuild + restore
│   │
│   ├── group_vars/
│   │   └── all/
│   │       ├── secrets.yml.template  # Template with {{placeholders}}
│   │       └── secrets.yml           # Actual secrets (gitignored)
│   │
│   ├── inventory/
│   │   └── hosts.yml           # Ansible inventory (gitignored in CI)
│   │
│   ├── Makefile                # Common operations wrapper
│   └── requirements.txt        # Python/Ansible dependencies
│
├── nextcloud/                  # Another app (same structure)
│   └── ...
│
├── ARCHITECTURE.md             # This file
├── INTEGRATION.md              # How to add new apps
└── README.md                   # Overview
```

### Key Conventions

- **One directory per application** - All app-specific files contained
- **Identical structure** - Every app follows the same layout
- **Shared infrastructure playbooks** - prepare-host is generic
- **App-specific deployment** - deploy-db and deploy-app are customized

---

## Jail Architecture

### Jail Types

#### 1. Database Jail (`<app>-db`)

**Purpose**: Isolated database server

**Characteristics:**
- Runs PostgreSQL/MySQL/MariaDB
- No public services exposed (internal only)
- Data stored in ZFS dataset: `/zroot/jails/data/<app>/db`
- Minimal package installation

**Example: semaphore-db**
```
IP: 192.168.1.50
Services: PostgreSQL 16
Data: /zroot/jails/data/semaphore/db → /var/db/postgres
```

#### 2. Application Jail (`<app>-app`)

**Purpose**: Run the application software

**Characteristics:**
- Web server, application runtime
- Public-facing (typically behind reverse proxy)
- Data stored in ZFS dataset: `/zroot/jails/data/<app>/app`
- Connects to database jail via network

**Example: semaphore-app**
```
IP: 192.168.1.51
Services: Semaphore (port 3000)
Data: /zroot/jails/data/semaphore/app → /var/semaphore
Connects to: semaphore-db:5432
```

### Jail Configuration Pattern

All jails are configured via `/etc/rc.conf.d/jail-forge`:

```sh
# Managed by jail-forge
jail_semaphore_db_enable="YES"
jail_semaphore_db_parameters="mount.devfs"
```

**Never edit manually** - Always use Ansible playbooks to modify.

### jail-forge Integration

jail-forge manages jails through:
- `/etc/jail.conf.d/<jail>.conf` - Jail definition
- `/etc/rc.conf.d/jail-forge` - Startup configuration
- `/usr/local/etc/jail-forge/<jail>/` - Per-jail configs

See: https://github.com/andoriyu/jail-forge

---

## Data Management

### ZFS Dataset Hierarchy

```
zroot/jails/                    # Root dataset for all jails
├── releases/                   # FreeBSD base systems
│   └── 13.5-RELEASE/
├── templates/                  # Jail templates (COW)
│   └── 13.5-RELEASE/
├── data/                       # Application data (PERSISTENT)
│   └── semaphore/
│       ├── db/                 # Database files
│       └── app/                # Application files
└── <jail-name>/                # Jail root filesystem (EPHEMERAL)
    ├── semaphore-db/
    └── semaphore-app/
```

### Critical Distinction

- **Ephemeral**: `/zroot/jails/<jail-name>/` - Can be deleted anytime
- **Persistent**: `/zroot/jails/data/<app>/` - Must survive jail destruction

### Mounting Pattern

Data datasets are mounted **into** jails at runtime:

```yaml
# In Ansible playbook
jail_mounts:
  - src: "/zroot/jails/data/semaphore/app"
    dest: "/var/semaphore"
    options: "rw"
```

This allows:
- Jail destruction without data loss
- Easy backup (just tar the data directory)
- ZFS snapshots of data only
- Quick disaster recovery

---

## Network Configuration

### IP Alias Mode

Jails use **IP alias mode** (not VNET):

```yaml
jail_vnet: false              # No virtualized network stack
jail_ip: "192.168.1.50"       # Alias on host interface
jail_interface: "em0"         # Host physical interface
```

**Why not VNET?**
- Simpler configuration
- No bridge/routing complexity
- Direct host network access
- Easier firewall rules

### Addressing Scheme

```
192.168.1.1       - Gateway/Router
192.168.1.x       - Host and other devices
192.168.1.50+     - Jail block
  .50 - semaphore-db
  .51 - semaphore-app
  .52 - nextcloud-db
  .53 - nextcloud-app
  ...
```

**Pattern**:
- Even IPs (.50, .52, .54) - Database jails
- Odd IPs (.51, .53, .55) - Application jails

### DNS & Service Discovery

Jails communicate via:
- **IP addresses** for inter-jail communication (db → app)
- **Hostnames** resolved via host's `/etc/hosts` or DNS

Example in application config:
```yaml
database_host: "192.168.1.50"  # Direct IP
database_port: 5432
```

---

## Execution Flow

### Initial Deployment (`make deploy` / `site.yml`)

```
1. prepare-host.yml
   ├─ Create ZFS datasets (/zroot/jails/data/<app>/{db,app})
   ├─ Download FreeBSD release (if needed)
   ├─ Create jail template
   └─ Install jail-forge

2. deploy-db.yml
   ├─ Create database jail
   ├─ Mount data dataset → /var/db/postgres
   ├─ Install PostgreSQL
   ├─ Initialize database cluster
   ├─ Create application database + user
   └─ Configure pg_hba.conf (allow app jail)

3. deploy-app.yml
   ├─ Create application jail
   ├─ Mount data dataset → /var/<app>
   ├─ Install application packages
   ├─ Configure application (DB connection, etc)
   ├─ Initialize application (migrations, setup)
   └─ Start application service
```

### Backup Flow (`make backup` / `backup.yml`)

```
1. Stop application service (graceful)
2. Create database dump
   └─ pg_dump → /zroot/jails/data/<app>/db/backup.sql
3. Create timestamped backup directory
   └─ /var/backups/<app>/YYYYMMDDTHHMMSS/
4. Copy data directories
   ├─ Database dump
   └─ Application data
5. Restart application service
```

**No jail filesystem backed up** - can rebuild from playbooks.

### Restore Flow (`make restore` / `restore.yml`)

```
1. Stop application + database services
2. Extract backup to data datasets
   ├─ Restore database dump
   └─ Restore application files
3. Restart database service
4. Run application migrations (if needed)
5. Restart application service
6. Verify health (API check, port listening)
```

### Disaster Recovery (`disaster-recovery.yml`)

**Complete rebuild from scratch + restore data**:

```
1. Destroy existing jails (if any)
2. Deploy fresh infrastructure
   ├─ prepare-host.yml
   ├─ deploy-db.yml
   └─ deploy-app.yml
3. Restore data from backup
   └─ restore.yml with backup_timestamp
4. Verify deployment
```

**Use case**: Host corruption, migration to new server, testing recovery procedures.

---

## Design Patterns

### Idempotency

All playbooks are **idempotent** - can run multiple times safely:

```yaml
- name: Create database
  postgresql_db:
    name: semaphore
    state: present  # Only creates if missing
```

Running `make deploy` twice doesn't break anything.

### Ansible Variables Hierarchy

```
1. group_vars/all/secrets.yml      # Per-app secrets
2. Playbook vars (vars:)           # Playbook-specific
3. Task vars (-e extra_vars)       # Runtime overrides
```

Example:
```yaml
# secrets.yml
semaphore_db_password: "secret123"

# In playbook
vars:
  db_name: "semaphore"

# Runtime override
ansible-playbook deploy-db.yml -e db_name=semaphore_test
```

### Secret Management

**Development**:
1. Copy `secrets.yml.template` → `secrets.yml`
2. Fill in actual values
3. **Never commit `secrets.yml`** (in `.gitignore`)

**CI/CD**:
1. Store secrets in GitHub Secrets
2. Workflow generates `secrets.yml` at runtime via `sed`
3. Deleted after workflow completes

### Health Checks

Every application must provide:

- **Service status**: `service <app> status` returns 0
- **Port listening**: Application binds to configured port
- **API endpoint**: HTTP endpoint returns success (e.g., `/api/ping`, `/status.php`)

Used by CI/CD to verify deployment success.

---

## Technology Stack

| Layer | Technology | Why |
|-------|------------|-----|
| Host OS | FreeBSD 13.x | ZFS, jails, stability |
| Isolation | FreeBSD jails | Lightweight, secure, fast |
| Storage | ZFS | Snapshots, datasets, reliability |
| Config Mgmt | Ansible | Idempotent, agentless, simple |
| CI/CD | GitHub Actions | Familiar, free for private repos |
| Jail Manager | jail-forge | Modern jail management |

---

## Security Considerations

### Jail Isolation

- Jails share kernel with host (not full VMs)
- Root in jail ≠ root on host (with proper securelevel)
- Network isolation via firewall rules
- No raw sockets in jails (configurable)

### Database Security

- PostgreSQL listens only on jail IP (not 0.0.0.0)
- `pg_hba.conf` restricts access to app jail IP only
- Strong passwords required (enforced in templates)
- Database dumps encrypted in backups (optional)

### Secret Handling

- Secrets never in Git repository
- CI/CD secrets stored in GitHub encrypted vault
- File permissions: `secrets.yml` is mode 600
- SSH keys generated per-deployment, rotated regularly

---

## Backup Strategy

### What Gets Backed Up

✅ **Data**:
- Database dumps (SQL)
- Application files (uploads, configs)
- User-generated content

✅ **Metadata**:
- Backup timestamp
- Application version
- Database schema version

❌ **Not Backed Up**:
- Operating system files
- Installed packages
- Jail filesystems
- Ansible playbooks (in Git)

### Backup Location

Default: `/var/backups/<app>/<timestamp>/`

```
/var/backups/semaphore/
├── 20251105T120000/
│   ├── db/
│   │   └── semaphore.sql
│   └── app/
│       └── data/
└── 20251105T180000/
    └── ...
```

### Retention Policy

- Configurable via `backup_retention_days` (default: 30)
- Old backups auto-deleted by cron
- ZFS snapshots optional (instant rollback)

---

## Monitoring & Observability

### Logs

Application logs mounted from jail to host:

```yaml
jail_mounts:
  - src: "/var/log/semaphore-jails/semaphore-app"
    dest: "/var/log/semaphore"
    options: "rw"
```

Access logs without entering jail: `tail -f /var/log/semaphore-jails/semaphore-app/*.log`

### Health Monitoring

Implemented in CI/CD workflow:
- Service status checks
- Port availability
- API endpoint responses
- Database connectivity

Can be extended to external monitoring (Prometheus, Nagios, etc.)

---

## Scalability Considerations

### Current Limitations

- Single-host deployment
- No load balancing
- Database not replicated
- Manual scaling

### Future Enhancements

- Multi-host jail clusters
- Database replication (PostgreSQL streaming replication)
- Reverse proxy jail (nginx/haproxy)
- Shared storage via NFS or iSCSI
- Automated scaling based on metrics

---

## References

- [FreeBSD Handbook - Jails](https://docs.freebsd.org/en/books/handbook/jails/)
- [jail-forge Documentation](https://github.com/andoriyu/jail-forge)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
- [ZFS Administration](https://docs.freebsd.org/en/books/handbook/zfs/)
