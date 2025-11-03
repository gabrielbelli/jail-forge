# Architecture Documentation

## Overview

This project implements a multi-jail architecture for Ansible Semaphore on FreeBSD using native jail tools, ZFS for storage management, and Ansible for orchestration.

## System Components

### 1. FreeBSD Host

The physical or virtual BSD machine that hosts all jails.

**Responsibilities:**
- Jail management via `jail(8)`
- Network routing and NAT via `pf(4)`
- Storage management via ZFS
- Resource allocation

**Key Files:**
- `/etc/jail.conf` - Main jail configuration
- `/usr/local/etc/jail.conf.d/*.conf` - Individual jail configs
- `/etc/pf.conf` - Firewall rules
- `/etc/rc.conf` - Service configuration

### 2. Database Jail (semaphore-db)

Isolated jail running PostgreSQL database.

**Specifications:**
- IP: 192.168.1.50 (configurable)
- PostgreSQL 15
- Dedicated ZFS dataset: `zroot/jails/data/db`
- No VNET (shared IP stack with host)

**Services:**
- postgresql (port 5432)
- syslog

**Data Storage:**
- Database files: `/var/db/postgres/data15/`
- Logs: `/var/db/postgres/data15/log/`

### 3. Application Jail (semaphore-app)

Isolated jail running Ansible Semaphore.

**Specifications:**
- IP: 192.168.1.51 (configurable)
- Semaphore v2.9.0
- Dedicated ZFS dataset: `zroot/jails/data/semaphore`
- No VNET (shared IP stack with host)

**Services:**
- semaphore (port 3000)
- syslog

**Data Storage:**
- Application: `/usr/local/bin/semaphore`
- Configuration: `/usr/local/etc/semaphore/`
- Temporary files: `/var/tmp/semaphore/`
- Logs: `/var/log/semaphore/`

## Network Architecture

### IP Allocation

```
Host Network: 192.168.1.0/24
├── Host:        192.168.1.10
├── Gateway:     192.168.1.1
├── DB Jail:     192.168.1.50
└── App Jail:    192.168.1.51
```

### Traffic Flow

```
Internet
    │
    ▼
[FreeBSD Host]
    │
    ├─[pf NAT]──────────────────┐
    │                           │
    ▼                           ▼
[semaphore-db]            [semaphore-app]
 192.168.1.50              192.168.1.51
 PostgreSQL:5432           Semaphore:3000
                                │
                                ▼
                          [Clients/Browser]
```

### Firewall Rules (pf)

```
# NAT for jail traffic
nat on em0 from 192.168.1.0/24 to any -> (em0)

# Allow jail-to-jail communication
pass in quick on em0 from 192.168.1.0/24
pass out quick on em0 to 192.168.1.0/24

# Allow outbound internet from jails
pass out on em0 from 192.168.1.0/24 to any
```

**Note:** Add host firewall rules to restrict external access to port 3000 as needed.

## Storage Architecture

### ZFS Layout

```
zroot/
└── jails/
    ├── base/                 # FreeBSD base system (shared)
    │   ├── bin/
    │   ├── lib/
    │   ├── usr/
    │   └── ...
    └── data/
        ├── db/               # Database jail (clone of base)
        │   ├── bin@ -> base
        │   ├── lib@ -> base
        │   └── var/db/postgres/  # PostgreSQL data
        └── semaphore/        # Application jail (clone of base)
            ├── bin@ -> base
            ├── lib@ -> base
            ├── usr/local/bin/semaphore
            └── usr/local/etc/semaphore/
```

### ZFS Features Used

- **Compression**: LZ4 on all datasets (transparent, fast)
- **Snapshots**: Point-in-time backups
- **Clones**: Space-efficient jail copies
- **Quotas**: Optional size limits per jail

### Storage Benefits

1. **Space Efficient**: Base system shared via null mounts
2. **Fast Backups**: ZFS snapshots are instant
3. **Easy Rollback**: Restore to any snapshot quickly
4. **Data Integrity**: ZFS checksumming
5. **Performance**: ARC caching, compression

## Ansible Architecture

### Inventory Structure

```yaml
all:
  children:
    jail_hosts:          # Physical BSD hosts
      hosts:
        bsd-host

    jails:              # Virtual (created by playbooks)
      children:
        database_jails:
          hosts:
            semaphore-db
        app_jails:
          hosts:
            semaphore-app

    all_jails:          # Group all jails
      children:
        database_jails
        app_jails
```

### Playbook Execution Flow

```
site.yml
  │
  ├── 01-prepare-host.yml
  │     ├── Create ZFS datasets
  │     ├── Download FreeBSD base
  │     ├── Configure jail.conf
  │     └── Configure pf
  │
  ├── 02-deploy-database.yml
  │     ├── Create jail (role: jail-base)
  │     └── Configure PostgreSQL (role: postgresql)
  │
  ├── 03-deploy-semaphore.yml
  │     ├── Create jail (role: jail-base)
  │     └── Configure Semaphore (role: semaphore)
  │
  └── 04-verify-deployment.yml
        ├── Check jail status
        ├── Test database
        ├── Test Semaphore
        └── Display summary
```

### Role Dependencies

```
jail-base (foundation)
  ├── Creates jail from base
  ├── Configures networking
  └── Bootstraps pkg
      │
      ├── postgresql (database setup)
      │     ├── Installs PostgreSQL
      │     ├── Initializes database
      │     ├── Creates users/databases
      │     └── Configures authentication
      │
      └── semaphore (application setup)
            ├── Downloads Semaphore binary
            ├── Creates configuration
            ├── Runs migrations
            └── Starts service
```

## Security Architecture

### Jail Isolation

Each jail provides:
- **Filesystem isolation**: Separate root filesystem
- **Process isolation**: Jailed processes can't see host
- **Network isolation**: Separate IP address
- **User isolation**: Jail root ≠ host root

### Security Layers

```
┌─────────────────────────────────────┐
│ Host Firewall (pf)                  │
├─────────────────────────────────────┤
│ Jail Boundaries                     │
│  ┌────────────┐  ┌────────────┐   │
│  │ DB Jail    │  │ App Jail   │   │
│  │ (isolated) │  │ (isolated) │   │
│  └────────────┘  └────────────┘   │
├─────────────────────────────────────┤
│ ZFS Permissions                     │
├─────────────────────────────────────┤
│ FreeBSD Security (MAC, Audit)       │
└─────────────────────────────────────┘
```

### Jail Parameters

Key security settings in jail configuration:

```
enforce_statfs = 2     # Restrict filesystem visibility
allow.raw_sockets = 0  # Disable raw sockets
allow.mount = 1        # Allow mounting (needed for nullfs)
allow.mount.zfs = 0    # Disable ZFS control from jail
devfs_ruleset = 4      # Restricted device access
```

## Deployment Architecture

### Infrastructure as Code Components

```
semaphore-ansible/
├── Configuration (declarative)
│   ├── inventory/hosts.yml        # What to deploy
│   ├── group_vars/*.yml           # How to configure
│   └── roles/*/defaults/*.yml     # Default settings
│
├── Orchestration (procedural)
│   ├── playbooks/*.yml            # Deployment steps
│   └── roles/*/tasks/*.yml        # Task execution
│
└── Convenience Layer
    ├── Makefile                   # User commands
    └── ansible.cfg                # Tool configuration
```

### Deployment Phases

**Phase 1: Bootstrap**
- Verify host requirements
- Install base packages
- Configure host system

**Phase 2: Infrastructure**
- Create ZFS datasets
- Download FreeBSD base
- Configure networking (pf)

**Phase 3: Jails**
- Create jail filesystems
- Configure jail.conf
- Start jails

**Phase 4: Services**
- Install PostgreSQL
- Install Semaphore
- Configure services

**Phase 5: Verification**
- Test connectivity
- Verify services
- Display status

## Scaling Considerations

### Vertical Scaling (Single Host)

**Current limitations:**
- 2 jails (db + app)
- Single PostgreSQL instance
- No load balancing

**Scaling within one host:**
- Add more application jails
- Increase PostgreSQL resources
- Use HAProxy jail for load balancing

### Horizontal Scaling (Multiple Hosts)

**For production scale:**
- Deploy to multiple BSD hosts
- PostgreSQL primary/replica setup
- External load balancer
- Shared storage (NFS/iSCSI for git repos)

Example multi-host inventory:

```yaml
jail_hosts:
  hosts:
    bsd-host-1:
      semaphore_instances: [app1, app2]
    bsd-host-2:
      semaphore_instances: [app3, app4]
    bsd-host-db:
      database_primary: true
```

### Performance Tuning

**Database:**
- Increase shared_buffers
- Tune work_mem
- Connection pooling (pgbouncer)

**Application:**
- Multiple Semaphore instances
- Task queue workers
- Increase max_parallel_tasks

**Storage:**
- Separate ZFS pools for data/logs
- SSD cache devices (L2ARC)
- Tuned recordsize for workload

## High Availability

### Current Setup

- **Single Point of Failure**: Both jails on one host
- **Recovery Time**: Manual intervention required
- **Data Protection**: ZFS snapshots only

### HA Improvements

**Database HA:**
```
PostgreSQL Primary (bsd-host-1)
    │
    ├── Streaming Replication
    │
    ▼
PostgreSQL Standby (bsd-host-2)
```

**Application HA:**
```
Load Balancer (HAProxy/Nginx)
    │
    ├── semaphore-app-1 (bsd-host-1)
    ├── semaphore-app-2 (bsd-host-1)
    ├── semaphore-app-3 (bsd-host-2)
    └── semaphore-app-4 (bsd-host-2)
```

**Shared State:**
- PostgreSQL for task state
- Shared NFS/iSCSI for git repos
- Redis for caching (optional)

## Monitoring Architecture

### Recommended Monitoring Stack

```
┌─────────────────────────────────────┐
│ Grafana (Visualization)             │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│ Prometheus (Metrics)                │
└──────────────┬──────────────────────┘
               │
    ┌──────────┼──────────┐
    ▼          ▼          ▼
[Host]    [DB Jail]  [App Jail]
  │           │           │
  ▼           ▼           ▼
node_exp  postgres_exp  custom_exp
```

### Metrics to Monitor

- **Host**: CPU, RAM, ZFS pool usage, network
- **Jails**: CPU per jail, RAM per jail, process count
- **PostgreSQL**: Connections, query time, locks, cache hit ratio
- **Semaphore**: Task queue length, success/failure rate, API response time

### Log Aggregation

Optional ELK stack:

```
Jails → Filebeat → Logstash → Elasticsearch → Kibana
```

## Disaster Recovery

### Backup Strategy

**Tier 1: Snapshots** (hourly)
- ZFS snapshots
- Fast, space-efficient
- On-site only

**Tier 2: Database Dumps** (daily)
- pg_dump to file
- Can be copied off-site
- Easy to restore

**Tier 3: Full System Backup** (weekly)
- ZFS send/receive to backup server
- Complete system state
- Slowest, most comprehensive

### Recovery Procedures

**Scenario 1: Corrupt Configuration**
- Rollback ZFS snapshot (30 seconds)

**Scenario 2: Failed Upgrade**
- Rollback ZFS snapshot (30 seconds)
- Or restore from backup (5 minutes)

**Scenario 3: Host Failure**
- Deploy to new host (10 minutes)
- Restore from backup (15 minutes)
- Update DNS/IPs (5 minutes)
- **Total RTO**: ~30 minutes

## Technology Choices

### Why FreeBSD Jails?

- ✅ Native to FreeBSD
- ✅ Lightweight (not VMs)
- ✅ Strong isolation
- ✅ Well-documented
- ✅ Stable and mature

**vs. Docker:**
- Jails: Better BSD integration, simpler, more stable on BSD
- Docker: Better for complex microservices, larger ecosystem

### Why ZFS?

- ✅ Data integrity (checksums)
- ✅ Instant snapshots
- ✅ Built-in compression
- ✅ Native to FreeBSD
- ✅ Easy management

### Why Ansible?

- ✅ Agentless (SSH only)
- ✅ Declarative
- ✅ Great for BSD
- ✅ Large community
- ✅ Easy to learn

**vs. Shell Scripts:**
- Ansible: Idempotent, readable, reusable
- Scripts: More control, simpler for BSD purists

## Future Enhancements

Potential improvements:

1. **VNET Support**: Full network stack isolation
2. **Multi-host**: Support for deploying across multiple BSD hosts
3. **HA Setup**: PostgreSQL replication, load balancing
4. **Monitoring**: Integrated Prometheus/Grafana
5. **SSL/TLS**: Automatic cert management with Let's Encrypt
6. **LDAP Integration**: Centralized authentication
7. **Backup Automation**: Scheduled, tested backups
8. **CI/CD**: Automated testing of playbooks

## References

- [FreeBSD Jails Handbook](https://docs.freebsd.org/en/books/handbook/jails/)
- [ZFS Administration Guide](https://docs.freebsd.org/en/books/handbook/zfs/)
- [PF User's Guide](https://www.freebsd.org/doc/handbook/firewalls-pf.html)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
- [Semaphore Documentation](https://docs.ansible-semaphore.com/)
