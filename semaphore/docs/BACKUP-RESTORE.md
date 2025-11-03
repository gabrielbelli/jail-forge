## Backup & Restore Guide (IaC Approach)

Complete guide for backing up and restoring Semaphore data using the Infrastructure as Code approach.

## Philosophy: Data vs Infrastructure

**With IaC, we separate concerns:**

- **Infrastructure** → Recreated from code (`ansible-playbook site.yml`)
- **Data** → Must be backed up (database, configs, certificates)

This means:
✅ **Faster backups** - Only data, not entire jails
✅ **Smaller backups** - MB instead of GB
✅ **Portable** - Restore to different infrastructure
✅ **Version controlled** - Infrastructure changes tracked in git

## What Gets Backed Up

### Essential (Always)
- **PostgreSQL database** - All your projects, templates, users
- **Semaphore runtime config** - Settings not in secrets.yml

### Optional (If configured)
- **TLS certificates** - Only if using existing/custom certs
- **Custom CA certificates** - Only if imported
- **ZFS snapshots** - Optional for instant rollback

### NOT Backed Up (Recreated from IaC)
- ❌ FreeBSD base system
- ❌ Installed packages
- ❌ Jail configuration
- ❌ Service files
- ❌ Self-signed certificates (regenerated)

## Quick Reference

### Most Common Workflows

```bash
# Regular backup (scheduled or manual)
make backup

# Disaster recovery (one command - most common!)
make disaster-recovery

# Step-by-step restore (more control)
make deploy    # 1. Infrastructure
make restore   # 2. Data

# List available backups
make list-backups
```

### Detailed Commands

```bash
# Backup
make backup
# or
ansible-playbook -i inventory/hosts.yml playbooks/backup.yml

# Combined disaster recovery (RECOMMENDED)
make disaster-recovery
# or
ansible-playbook -i inventory/hosts.yml playbooks/disaster-recovery.yml

# Separate steps (more control)
ansible-playbook -i inventory/hosts.yml site.yml           # 1. Infrastructure
ansible-playbook -i inventory/hosts.yml playbooks/restore.yml  # 2. Data

# List backups
ls -lh /var/backups/semaphore/
```

## Backup

### Manual Backup

```bash
ansible-playbook -i inventory/hosts.yml playbooks/backup.yml
```

### What Happens

1. **Creates timestamped directory**: `/var/backups/semaphore/20240130T120000/`
2. **Dumps database**: PostgreSQL custom format dump
3. **Archives config**: Semaphore settings (excludes logs)
4. **Backs up certs**: If using existing certificates
5. **Backs up CAs**: If custom CAs imported
6. **Creates metadata**: backup-info.txt with details
7. **Cleans old backups**: Based on retention policy

### Backup Structure

```
/var/backups/semaphore/20240130T120000/
├── backup-info.txt              # Metadata and restore instructions
├── database.dump                # PostgreSQL dump (essential)
├── semaphore-data.tar.gz       # Runtime configuration
├── certificates.tar.gz          # TLS certs (if using existing)
└── custom-ca.tar.gz            # Custom CAs (if configured)
```

### Configuration

In `group_vars/all/vars.yml`:

```yaml
# Backup location on BSD host
backup_location: "/var/backups/semaphore"

# ============================================
# BACKUP RETENTION OPTIONS (Choose one or both)
# ============================================

# Age-based retention: Remove backups older than N days
# Uncomment to enable:
# backup_retention_days: 30

# Count-based retention: Keep only the last N backups (newest)
# Recommended: 10 for daily backups, 7 for weekly
backup_retention_count: 10

# Optional: Compress into single archive
backup_compress: false

# Optional: ZFS snapshots for quick rollback
backup_zfs_snapshots: false
```

**Retention Strategies:**

| Strategy | Variable | Use Case | Example |
|----------|----------|----------|---------|
| **Count-based** (recommended) | `backup_retention_count: 10` | Fixed number of backups regardless of age | Keep last 10 backups |
| **Age-based** | `backup_retention_days: 30` | Time-based cleanup | Remove backups older than 30 days |
| **Both** | Use both variables | Hybrid approach | Keep last 10 backups AND remove any older than 90 days |
| **None** | Comment out both | Manual cleanup only | No automatic deletion |

### Automated Backups with Cron

For production environments, schedule automated backups using cron on the BSD host.

#### Setup Steps

**1. Create vault password file (if using encrypted secrets):**

```bash
# On BSD host
echo "your-vault-password" > /root/.vault_pass
chmod 600 /root/.vault_pass
```

**2. Edit root crontab:**

```bash
crontab -e
```

**3. Add backup schedule** (choose one or combine):

#### Daily Backup (Recommended)

```bash
# Daily backup at 2 AM with log rotation
0 2 * * * cd /root/semaphore-ansible && /usr/local/bin/ansible-playbook -i inventory/hosts.yml playbooks/backup.yml --vault-password-file /root/.vault_pass >> /var/log/semaphore-backup.log 2>&1
```

**Retention:** Set `backup_retention_count: 10` to keep last 10 daily backups (10 days of history)

#### Weekly Backup

```bash
# Weekly backup on Sundays at 3 AM
0 3 * * 0 cd /root/semaphore-ansible && /usr/local/bin/ansible-playbook -i inventory/hosts.yml playbooks/backup.yml --vault-password-file /root/.vault_pass >> /var/log/semaphore-backup.log 2>&1
```

**Retention:** Set `backup_retention_count: 12` to keep 3 months of weekly backups

#### Hourly Backup (High-Change Environments)

```bash
# Every hour at minute 0
0 * * * * cd /root/semaphore-ansible && /usr/local/bin/ansible-playbook -i inventory/hosts.yml playbooks/backup.yml --vault-password-file /root/.vault_pass >> /var/log/semaphore-backup.log 2>&1
```

**Retention:** Set `backup_retention_count: 48` to keep 2 days of hourly backups

#### Multi-Tier Backup Strategy

```bash
# Hourly backups (keep 24 hours)
0 * * * * cd /root/semaphore-ansible && /usr/local/bin/ansible-playbook -i inventory/hosts.yml playbooks/backup.yml --vault-password-file /root/.vault_pass -e backup_location=/var/backups/semaphore-hourly -e backup_retention_count=24 >> /var/log/semaphore-backup-hourly.log 2>&1

# Daily backups at 2 AM (keep 30 days)
0 2 * * * cd /root/semaphore-ansible && /usr/local/bin/ansible-playbook -i inventory/hosts.yml playbooks/backup.yml --vault-password-file /root/.vault_pass -e backup_location=/var/backups/semaphore-daily -e backup_retention_count=30 >> /var/log/semaphore-backup-daily.log 2>&1

# Weekly backups on Sunday at 3 AM (keep 12 weeks)
0 3 * * 0 cd /root/semaphore-ansible && /usr/local/bin/ansible-playbook -i inventory/hosts.yml playbooks/backup.yml --vault-password-file /root/.vault_pass -e backup_location=/var/backups/semaphore-weekly -e backup_retention_count=12 >> /var/log/semaphore-backup-weekly.log 2>&1
```

#### Monitoring Backup Jobs

**View recent backup logs:**

```bash
# Last backup run
tail -50 /var/log/semaphore-backup.log

# Check for errors
grep -i error /var/log/semaphore-backup.log

# View all backup runs today
grep "$(date +%Y-%m-%d)" /var/log/semaphore-backup.log
```

**Get notifications on failure:**

```bash
# Cron with email notification (requires mail configured)
MAILTO=admin@example.com
0 2 * * * cd /root/semaphore-ansible && /usr/local/bin/ansible-playbook -i inventory/hosts.yml playbooks/backup.yml --vault-password-file /root/.vault_pass || echo "Semaphore backup failed on $(hostname)" | mail -s "Backup Failure Alert" admin@example.com
```

**Log rotation for backup logs:**

```bash
# Add to /etc/newsyslog.conf or /etc/newsyslog.conf.d/semaphore-backup.conf
/var/log/semaphore-backup.log        root:wheel      644  7     *    @T00  JC
/var/log/semaphore-backup-hourly.log root:wheel      644  7     *    @T00  JC
/var/log/semaphore-backup-daily.log  root:wheel      644  30    *    @T00  JC
/var/log/semaphore-backup-weekly.log root:wheel      644  90    *    @T00  JC
```

### Automated ZFS Snapshots

ZFS snapshots provide instant point-in-time recovery but don't replace full backups.

#### Enable in Configuration

In `group_vars/all/vars.yml`:

```yaml
backup_zfs_snapshots: true  # Enable snapshot creation during backups
```

#### Manual ZFS Snapshot Commands

```bash
# Create snapshots of both jails
zfs snapshot zroot/jails/data/semaphore-db@manual-$(date +%Y%m%d-%H%M%S)
zfs snapshot zroot/jails/data/semaphore-app@manual-$(date +%Y%m%d-%H%M%S)

# List snapshots
zfs list -t snapshot | grep jails

# Rollback to snapshot
service jail stop semaphore-app
zfs rollback zroot/jails/data/semaphore-app@backup-20250103T020000
service jail start semaphore-app

# Destroy old snapshot
zfs destroy zroot/jails/data/semaphore-db@backup-20240101T020000
```

#### Automated Snapshot Schedule

**Frequent snapshots for quick rollback:**

```bash
# Edit root crontab
crontab -e

# Every 6 hours - snapshot both jails
0 */6 * * * zfs snapshot zroot/jails/data/semaphore-db@auto-$(date +\%Y\%m\%d-\%H\%M\%S)
0 */6 * * * zfs snapshot zroot/jails/data/semaphore-app@auto-$(date +\%Y\%m\%d-\%H\%M\%S)

# Daily cleanup - keep last 7 days of snapshots
0 4 * * * for snap in $(zfs list -H -t snapshot -o name | grep 'jails/data/semaphore.*@auto-' | head -n -28); do zfs destroy $snap; done
```

**Recommended snapshot strategy:**

```bash
# Hourly snapshots (keep 48 hours)
0 * * * * zfs snapshot zroot/jails/data/semaphore-db@hourly-$(date +\%Y\%m\%d-\%H\%M) && zfs snapshot zroot/jails/data/semaphore-app@hourly-$(date +\%Y\%m\%d-\%H\%M)

# Daily snapshots (keep 30 days)
0 2 * * * zfs snapshot zroot/jails/data/semaphore-db@daily-$(date +\%Y\%m\%d) && zfs snapshot zroot/jails/data/semaphore-app@daily-$(date +\%Y\%m\%d)

# Weekly snapshots (keep 12 weeks)
0 3 * * 0 zfs snapshot zroot/jails/data/semaphore-db@weekly-$(date +\%Y-W\%U) && zfs snapshot zroot/jails/data/semaphore-app@weekly-$(date +\%Y-W\%U)

# Cleanup hourly snapshots older than 48 hours
0 5 * * * for snap in $(zfs list -H -t snapshot -o name -s creation | grep '@hourly-' | head -n -48); do zfs destroy $snap; done

# Cleanup daily snapshots older than 30 days
0 6 * * * for snap in $(zfs list -H -t snapshot -o name -s creation | grep '@daily-' | head -n -30); do zfs destroy $snap; done

# Cleanup weekly snapshots older than 12 weeks
0 7 * * 0 for snap in $(zfs list -H -t snapshot -o name -s creation | grep '@weekly-' | head -n -12); do zfs destroy $snap; done
```

#### ZFS Snapshot Best Practices

**Advantages:**
- ⚡ **Instant creation** (seconds)
- ⚡ **Instant rollback** (seconds)
- 💾 **Space efficient** (only changed blocks)
- 🔍 **Browse old versions** (mount read-only)

**Limitations:**
- ❌ **Not a backup** (same disk, same pool)
- ❌ **Hardware failure** loses snapshots
- ❌ **Corruption** can affect snapshots

**When to use snapshots:**
- ✅ Before risky changes (config updates, upgrades)
- ✅ Hourly/frequent protection against mistakes
- ✅ Quick rollback without restore process
- ✅ **Combined with off-site backups** for complete protection

**Complete backup strategy:**
```
Local snapshots  → Instant rollback (seconds)
       ↓
Local backups    → Disaster recovery on same host (minutes)
       ↓
Off-site backups → Complete site failure protection (hours)
```

### Complete Cron Setup Example

```bash
# On BSD host: crontab -e

# =============================================================================
# Semaphore Backup and Snapshot Schedule
# =============================================================================

# Vault password file location
SHELL=/bin/sh
PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin
ANSIBLE=/usr/local/bin/ansible-playbook
PLAYBOOK=/root/semaphore-ansible

# Email notifications (optional - requires mail setup)
MAILTO=admin@example.com

# -----------------------------------------------------------------------------
# ZFS Snapshots (Instant rollback capability)
# -----------------------------------------------------------------------------
# Hourly snapshots - keep 48 hours
0 * * * * zfs snapshot zroot/jails/data/semaphore-db@hourly-$(date +\%Y\%m\%d-\%H) && zfs snapshot zroot/jails/data/semaphore-app@hourly-$(date +\%Y\%m\%d-\%H)

# Daily snapshots at 2 AM - keep 30 days
0 2 * * * zfs snapshot zroot/jails/data/semaphore-db@daily-$(date +\%Y\%m\%d) && zfs snapshot zroot/jails/data/semaphore-app@daily-$(date +\%Y\%m\%d)

# Cleanup old hourly snapshots (keep last 48)
5 * * * * for snap in $(zfs list -H -t snapshot -o name -s creation | grep '@hourly-' | head -n -96); do zfs destroy $snap 2>/dev/null; done

# Cleanup old daily snapshots (keep last 30)
10 2 * * * for snap in $(zfs list -H -t snapshot -o name -s creation | grep '@daily-' | head -n -60); do zfs destroy $snap 2>/dev/null; done

# -----------------------------------------------------------------------------
# Full Backups (For disaster recovery)
# -----------------------------------------------------------------------------
# Daily backup at 2:30 AM - keep 10 days
30 2 * * * cd $PLAYBOOK && $ANSIBLE -i inventory/hosts.yml playbooks/backup.yml --vault-password-file /root/.vault_pass >> /var/log/semaphore-backup.log 2>&1

# Weekly backup on Sunday at 3 AM - keep 12 weeks (separate location)
0 3 * * 0 cd $PLAYBOOK && $ANSIBLE -i inventory/hosts.yml playbooks/backup.yml --vault-password-file /root/.vault_pass -e backup_location=/var/backups/semaphore-weekly -e backup_retention_count=12 >> /var/log/semaphore-backup-weekly.log 2>&1

# -----------------------------------------------------------------------------
# Off-site Backup Sync (Optional)
# -----------------------------------------------------------------------------
# Sync to remote server daily at 4 AM
0 4 * * * rsync -az --delete /var/backups/semaphore/ backup-server:/offsite-backups/semaphore/ >> /var/log/semaphore-rsync.log 2>&1

# -----------------------------------------------------------------------------
# Monitoring and Cleanup
# -----------------------------------------------------------------------------
# Check backup disk space daily at 6 AM
0 6 * * * df -h /backups | tail -1 | awk '{if (int($5) > 80) print "Backup disk usage at "$5" on $(hostname)" }' | mail -s "Backup Disk Space Warning" $MAILTO
```

## Restore

### Prerequisites

1. **Infrastructure must be deployed first**:
   ```bash
   ansible-playbook -i inventory/hosts.yml site.yml
   ```

2. **Know your backup timestamp**:
   ```bash
   ls /var/backups/semaphore/
   # Output: 20240130T120000  20240131T120000  20240201T120000
   ```

### Interactive Restore

```bash
ansible-playbook -i inventory/hosts.yml playbooks/restore.yml
```

You'll be prompted for:
1. **Backup timestamp** to restore
2. **Confirmation** (must type "yes")

### What Happens

1. **Validates** backup exists
2. **Shows** backup information
3. **Stops** Semaphore service
4. **Drops & recreates** database
5. **Restores** database from dump
6. **Extracts** configuration files
7. **Restores** certificates (if any)
8. **Restores** custom CAs (if any)
9. **Starts** Semaphore service
10. **Verifies** everything works

### Non-Interactive Restore

```bash
ansible-playbook -i inventory/hosts.yml playbooks/restore.yml \
  -e "backup_timestamp=20240130T120000" \
  -e "confirm_restore=yes"
```

## Common Workflows

### Workflow 1: Disaster Recovery (MOST COMMON)

**When:** Complete host failure, migration to new hardware, or major infrastructure rebuild

**One-Command Approach** (Recommended):

```bash
# Single command does everything
make disaster-recovery
```

This will:
1. Prompt for backup timestamp
2. Deploy complete infrastructure
3. Restore data from backup
4. Verify everything works
5. Show final report

**Two-Step Approach** (More Control):

```bash
# Step 1: Deploy infrastructure
make deploy

# Step 2: Restore data
make restore
```

Use when you want to verify infrastructure before restoring data.

### Workflow 2: Regular Backups

**When:** Daily/weekly scheduled backups

```bash
# Manual backup
make backup

# Automated (crontab)
0 2 * * * cd /root/semaphore-ansible && make backup
```

### Workflow 3: Quick Restore (Data Only)

**When:** Need to restore data but infrastructure is already deployed

```bash
make restore
```

Use when:
- Bad configuration change
- Accidental data deletion
- Want to restore to earlier state

### Workflow 4: Cross-Environment Migration

**When:** Copy production data to staging/test

```bash
# On production
make backup

# Copy backup to staging host
scp -r /var/backups/semaphore/20240130T120000 staging-host:/var/backups/semaphore/

# On staging
make disaster-recovery
# Enter production backup timestamp
```

## Disaster Recovery Scenarios

### Scenario 1: Complete Host Failure (Use disaster-recovery)

**Situation**: BSD host died, need to restore to new hardware

**Steps:**

```bash
# 1. On new BSD host, clone the repo
git clone <your-repo>
cd semaphore-ansible

# 2. Update inventory with new host IP
vim inventory/hosts.yml

# 3. Copy backup from old host (or restore from off-site backup)
scp -r old-host:/var/backups/semaphore /backups/

# 4. Run disaster recovery (ONE COMMAND)
make disaster-recovery
# Enter backup timestamp: 20240130T120000
# Confirm: yes

# Done!
```

**RTO (Recovery Time Objective)**: ~15-20 minutes

**Why this is better:**
- ✅ One command instead of two
- ✅ Single confirmation prompt
- ✅ Integrated verification
- ✅ Clear progress indicators
- ✅ Final report with next steps

### Scenario 2: Bad Configuration Change

**Situation**: Made a configuration change that broke Semaphore

**Solution A: Restore from backup (full)**

```bash
ansible-playbook -i inventory/hosts.yml playbooks/restore.yml
```

**Solution B: Quick rollback with ZFS (if enabled)**

```bash
# List snapshots
zfs list -t snapshot | grep jails

# Rollback
service jail stop semaphore-app
zfs rollback zroot/jails/data/semaphore@backup-20240130T120000
service jail start semaphore-app
```

### Scenario 3: Database Corruption

**Situation**: Database is corrupted but configuration is OK

**Steps:**

```bash
# 1. Stop Semaphore
jexec semaphore-app service semaphore stop

# 2. Manual database restore
BACKUP_TS=20240130T120000
jexec semaphore-db su - postgres -c "dropdb semaphore"
jexec semaphore-db su - postgres -c "createdb -O semaphore semaphore"
jexec semaphore-db su - postgres -c "pg_restore -d semaphore /var/backups/semaphore/$BACKUP_TS/database.dump"

# 3. Start Semaphore
jexec semaphore-app service semaphore start
```

### Scenario 4: Accidental Data Deletion

**Situation**: Accidentally deleted projects in Semaphore UI

**Steps:**

```bash
# Restore just the database
ansible-playbook -i inventory/hosts.yml playbooks/restore.yml
# When prompted, select recent backup before deletion
```

## Backup Best Practices

### 1. Test Restores Regularly

```bash
# Monthly drill: Restore to test environment
ansible-playbook -i inventory/test-hosts.yml site.yml
ansible-playbook -i inventory/test-hosts.yml playbooks/restore.yml
```

### 2. Off-Site Backups

```bash
# Rsync to remote server
rsync -avz /var/backups/semaphore/ backup-server:/offsite-backups/semaphore/

# Or use ZFS send
zfs send zroot/jails/data/db@backup-latest | ssh backup-server zfs receive tank/var/backups/semaphore-db
```

### 3. Verify Backups

```bash
# Check backup completed successfully
ls -lh /var/backups/semaphore/$(date +%Y%m%d)*/

# Verify database dump is valid
pg_restore --list /var/backups/semaphore/latest/database.dump
```

### 4. Monitor Backup Size

```bash
# Track backup growth
du -sh /var/backups/semaphore/*/ | tail -10

# Alert if backup size changes dramatically
# (might indicate data loss or corruption)
```

### 5. Retention Policy

Default: 30 days

Adjust based on:
- **Compliance requirements**
- **Storage capacity**
- **Recovery needs**

```yaml
# More aggressive retention
backup_retention_days: 7

# Longer retention
backup_retention_days: 90
```

## Advanced Topics

### Selective Restore

Restore only database, not configuration:

```bash
# Manual selective restore
BACKUP_TS=20240130T120000

# Database only
jexec semaphore-db su - postgres -c "dropdb semaphore"
jexec semaphore-db su - postgres -c "createdb -O semaphore semaphore"
jexec semaphore-db su - postgres -c "pg_restore -d semaphore /var/backups/semaphore/$BACKUP_TS/database.dump"
```

### Encrypted Backups

```bash
# Encrypt backup directory
tar -czf - /var/backups/semaphore/20240130T120000/ | \
  openssl enc -aes-256-cbc -e -out semaphore-backup-encrypted.tar.gz.enc

# Decrypt
openssl enc -aes-256-cbc -d -in semaphore-backup-encrypted.tar.gz.enc | \
  tar -xzf -
```

### Cross-Environment Migration

Move production data to staging:

```bash
# 1. Backup production
ansible-playbook -i inventory/production.yml playbooks/backup.yml

# 2. Copy backup to staging host
scp -r prod-host:/var/backups/semaphore/latest staging-host:/var/backups/semaphore/

# 3. Deploy staging infrastructure
ansible-playbook -i inventory/staging.yml site.yml

# 4. Restore to staging
ansible-playbook -i inventory/staging.yml playbooks/restore.yml
```

### Point-in-Time Recovery

With WAL archiving (advanced PostgreSQL setup):

```bash
# Enable WAL archiving in postgresql role
# Then restore to specific timestamp
pg_restore --until='2024-01-30 12:00:00'
```

## Troubleshooting

### Backup Fails - Disk Full

```bash
# Check disk space
df -h /backups

# Clean old backups manually
rm -rf /var/backups/semaphore/$(date -d '60 days ago' +%Y%m%d)*

# Or adjust retention
# Edit secrets.yml: backup_retention_days: 7
```

### Restore Fails - Permission Denied

```bash
# Ensure backup files are readable
chmod -R 755 /var/backups/semaphore/

# Check ownership
chown -R root:wheel /var/backups/semaphore/
```

### Database Restore Errors

```bash
# View detailed error
jexec semaphore-db su - postgres -c "pg_restore -v -d semaphore /path/to/dump"

# Common fix: Drop connections first
jexec semaphore-db su - postgres -c "
SELECT pg_terminate_backend(pg_stat_activity.pid)
FROM pg_stat_activity
WHERE pg_stat_activity.datname = 'semaphore';
"
```

### Semaphore Won't Start After Restore

```bash
# Check logs
jexec semaphore-app tail -f /var/log/semaphore/semaphore.log

# Verify database connection
jexec semaphore-app cat /usr/local/etc/semaphore/config.json | grep -A5 postgres

# Test database connectivity
jexec semaphore-app nc -zv 192.168.1.50 5432
```

## Summary

**Backup workflow:**
1. Run `make backup` (or cron job)
2. Verify backup completed
3. Test restore periodically

**Restore workflow:**
1. Deploy infrastructure: `ansible-playbook site.yml`
2. Restore data: `ansible-playbook playbooks/restore.yml`
3. Verify and test

**Key points:**
- ✅ Data-only backups (fast, small)
- ✅ Infrastructure from code (reproducible)
- ✅ Regular testing (confidence)
- ✅ Off-site copies (disaster recovery)

**RTO targets:**
- Infrastructure deployment: 10 minutes
- Data restore: 5 minutes
- Total RTO: **~15 minutes**
