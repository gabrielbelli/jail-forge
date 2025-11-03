# Operations Guide

Day-to-day operations for managing Ansible Semaphore on BSD jails.

## Daily Operations

### Check System Health

```bash
# Quick health check
make status

# Detailed jail info
ssh root@BSD_HOST
jls -v

# Check resource usage
jexec semaphore-app top
jexec semaphore-db top
```

### View Logs

```bash
# Semaphore application logs
make logs-app

# Database logs
make logs-db

# System logs
ssh root@BSD_HOST
tail -f /var/log/messages
```

### Access Jails

```bash
# Shell in application jail
make shell-app
# or
jexec semaphore-app /bin/sh

# Shell in database jail
make shell-db
# or
jexec semaphore-db /bin/sh
```

## Maintenance Tasks

### Update Semaphore

```bash
# Interactive - prompts for version
make update

# Specify version
ansible-playbook -i inventory/hosts.yml playbooks/update-semaphore.yml \
  -e "semaphore_new_version=v2.10.0"
```

**Update process:**
1. Stops Semaphore service
2. Backs up current binary
3. Downloads new version
4. Runs database migrations
5. Restarts service
6. Verifies it's running

### Update FreeBSD Base

```bash
# On BSD host
freebsd-update fetch install

# Update jails
jexec semaphore-db freebsd-update fetch install
jexec semaphore-app freebsd-update fetch install

# Restart jails
service jail restart
```

### Update PostgreSQL

```bash
# Check current version
jexec semaphore-db pkg info postgresql15-server

# Update to patch version
jexec semaphore-db pkg upgrade

# For major version upgrade (15 -> 16), requires migration
# See PostgreSQL upgrade documentation
```

## Backup and Restore

### Create Backups

```bash
# Full backup (ZFS snapshots + DB dump)
make backup

# Manual ZFS snapshot
zfs snapshot zroot/jails/data/db@manual-$(date +%Y%m%d)
zfs snapshot zroot/jails/data/semaphore@manual-$(date +%Y%m%d)

# Manual database dump
jexec semaphore-db su - postgres -c \
  "pg_dump -Fc semaphore -f /tmp/semaphore-$(date +%Y%m%d).dump"
```

### List Backups

```bash
# List ZFS snapshots
zfs list -t snapshot | grep jails

# List database dumps
ls -lh /var/backups/semaphore/
```

### Restore from Backup

**Restore from ZFS snapshot:**

```bash
# Stop jails
service jail stop semaphore-app
service jail stop semaphore-db

# Rollback to snapshot
zfs rollback zroot/jails/data/db@backup-TIMESTAMP
zfs rollback zroot/jails/data/semaphore@backup-TIMESTAMP

# Start jails
service jail start semaphore-db
service jail start semaphore-app
```

**Restore database only:**

```bash
# Stop Semaphore
jexec semaphore-app service semaphore stop

# Drop and recreate database
jexec semaphore-db su - postgres -c "dropdb semaphore"
jexec semaphore-db su - postgres -c "createdb semaphore -O semaphore"

# Restore from dump
jexec semaphore-db su - postgres -c \
  "pg_restore -d semaphore /path/to/backup.dump"

# Start Semaphore
jexec semaphore-app service semaphore start
```

### Automated Backups

Create a cron job on BSD host:

```bash
# Edit root's crontab
crontab -e

# Add daily backup at 2 AM
0 2 * * * cd /root/semaphore-ansible && ansible-playbook -i inventory/hosts.yml playbooks/backup.yml > /var/log/semaphore-backup.log 2>&1
```

## Performance Tuning

### PostgreSQL Tuning

Edit `roles/postgresql/defaults/main.yml`:

```yaml
# For systems with 8GB RAM
postgres_shared_buffers: "2GB"
postgres_effective_cache_size: "6GB"
postgres_maintenance_work_mem: "512MB"
postgres_work_mem: "16MB"
postgres_wal_buffers: "16MB"
```

Redeploy:
```bash
ansible-playbook -i inventory/hosts.yml playbooks/02-deploy-database.yml --tags config
```

### ZFS Tuning

```bash
# Enable compression
zfs set compression=lz4 zroot/jails

# Set ARC cache limits (in /boot/loader.conf)
vfs.zfs.arc_max="2G"

# Tune record size for database
zfs set recordsize=8K zroot/jails/data/db
```

### Jail Resource Limits

Edit jail configuration to add resource limits:

```bash
# /usr/local/etc/jail.conf.d/semaphore-app.conf
semaphore-app {
    # ... existing config ...

    # Limit to 2GB RAM
    enforce_statfs = 2;
    allow.mount = 0;

    # CPU limits (using rctl)
    exec.start += "rctl -a jail:${name}:pcpu:deny=200";
}
```

## Monitoring

### Basic Health Checks

```bash
# Check if services are responding
curl http://192.168.1.51:3000/api/ping

# Check database connections
jexec semaphore-db psql -U postgres -c \
  "SELECT count(*) FROM pg_stat_activity;"

# Check disk usage
zfs list -o name,used,avail,refer,mountpoint
```

### Set Up Monitoring (Optional)

Consider integrating with:
- **Prometheus + Grafana**: Metrics collection
- **Nagios/Icinga**: Service monitoring
- **ELK Stack**: Log aggregation

Example check for uptime monitoring:

```bash
# /usr/local/bin/check_semaphore.sh
#!/bin/sh
response=$(curl -s -o /dev/null -w "%{http_code}" http://192.168.1.51:3000/api/ping)
if [ "$response" -eq 200 ]; then
    echo "OK: Semaphore is running"
    exit 0
else
    echo "CRITICAL: Semaphore is down (HTTP $response)"
    exit 2
fi
```

## Troubleshooting

### Semaphore Won't Start

```bash
# Check service status
jexec semaphore-app service semaphore status

# Check logs
jexec semaphore-app tail -f /var/log/semaphore/semaphore.log

# Check configuration
jexec semaphore-app cat /usr/local/etc/semaphore/config.json

# Test database connection
jexec semaphore-app nc -zv 192.168.1.50 5432

# Try starting manually
jexec semaphore-app semaphore service --config /usr/local/etc/semaphore
```

### Database Issues

```bash
# Check PostgreSQL is running
jexec semaphore-db service postgresql status

# Check for errors
jexec semaphore-db tail -f /var/db/postgres/data15/log/*.log

# Check connections
jexec semaphore-db psql -U postgres -c \
  "SELECT * FROM pg_stat_activity WHERE datname = 'semaphore';"

# Restart PostgreSQL
jexec semaphore-db service postgresql restart
```

### Network Issues

```bash
# Test from app to db
jexec semaphore-app ping 192.168.1.50

# Check firewall rules
pfctl -sr | grep 192.168.1

# Check NAT
pfctl -sn

# Test external connectivity
jexec semaphore-app ping 8.8.8.8
```

### Jail Won't Start

```bash
# Check jail configuration syntax
jail -f /etc/jail.conf -c test

# Check for conflicting IPs
jls | grep 192.168.1.51

# Check ZFS datasets
zfs list | grep jails

# Start with verbose output
jail -v -c semaphore-app
```

### High Resource Usage

```bash
# Check top processes in jail
jexec semaphore-app top

# Check PostgreSQL connections
jexec semaphore-db psql -U postgres -c \
  "SELECT count(*), state FROM pg_stat_activity GROUP BY state;"

# Check ZFS I/O
zpool iostat -v 1

# Check for long-running queries
jexec semaphore-db psql -U postgres -c \
  "SELECT pid, now() - query_start as duration, query
   FROM pg_stat_activity
   WHERE state != 'idle'
   ORDER BY duration DESC;"
```

## Security Operations

### Rotate Secrets

```bash
# Generate new secrets
openssl rand -hex 32

# Update in inventory
vim inventory/hosts.yml

# Redeploy Semaphore
ansible-playbook -i inventory/hosts.yml playbooks/03-deploy-semaphore.yml
```

### Update SSL Certificates

If using reverse proxy:

```bash
# Copy new certificates to jail
scp cert.pem key.pem root@BSD_HOST:/tmp/
jexec nginx-proxy cp /tmp/cert.pem /usr/local/etc/ssl/
jexec nginx-proxy service nginx reload
```

### Audit Access

```bash
# Check Semaphore users
# Via Web UI: Settings -> Users

# Check PostgreSQL roles
jexec semaphore-db psql -U postgres -c "\du"

# Review jail access logs
jexec semaphore-app last

# Check SSH access to host
last | grep root
```

## Disaster Recovery

### Complete System Rebuild

```bash
# 1. Ensure you have backups
make backup

# 2. Destroy existing infrastructure
make destroy

# 3. Redeploy from scratch
make deploy

# 4. Restore data from backup
# (see Restore from Backup section above)
```

### Migrate to New Host

```bash
# On old host: Create backup
make backup

# Copy backup files to new host
scp -r /var/backups/semaphore NEW_HOST:/backups/

# On new host: Deploy infrastructure
make deploy

# Restore data
# (follow restore procedures)
```

## Getting Help

1. Check logs first: `make logs-app` and `make logs-db`
2. Review this operations guide
3. Check [FreeBSD Handbook](https://docs.freebsd.org/en/books/handbook/)
4. Review [Semaphore docs](https://docs.ansible-semaphore.com/)
5. Open a GitHub issue with:
   - FreeBSD version
   - Error messages
   - Relevant logs
   - Steps to reproduce
