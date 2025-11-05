# Adding a New Application to Jail-Forge

This guide walks through integrating a new application into the jail-forge monorepo.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Step-by-Step Integration](#step-by-step-integration)
- [Playbook Customization](#playbook-customization)
- [Testing Your Integration](#testing-your-integration)
- [GitHub Secrets Configuration](#github-secrets-configuration)
- [Example: Nextcloud](#example-nextcloud)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

Before starting, gather:

- **Application name** (e.g., `nextcloud`, `jellyfin`)
- **Database requirements** (PostgreSQL, MySQL, or none)
- **Service port** (where the app listens)
- **Health check endpoint** (e.g., `/status.php`, `/health`)
- **FreeBSD package name** or installation method
- **Configuration requirements** (file paths, env vars)

---

## Step-by-Step Integration

### Step 1: Create Application Directory

Copy the semaphore template as a starting point:

```bash
# From repo root
cp -r semaphore/ <appname>/
cd <appname>/
```

Replace `<appname>` with your application (e.g., `nextcloud`).

### Step 2: Update secrets.yml.template

Edit `group_vars/all/secrets.yml.template`:

```yaml
---
# =============================================================================
# DATABASE SECRETS
# =============================================================================
postgres_admin_password: "{{DB_PASSWORD}}"
<appname>_db_name: "<appname>"
<appname>_db_user: "<appname>"
<appname>_db_password: "{{DB_PASSWORD}}"

# =============================================================================
# APPLICATION SECRETS
# =============================================================================
<appname>_admin_user: "admin"
<appname>_admin_email: "admin@example.com"
<appname>_admin_password: "{{<APPNAME>_ADMIN_PASSWORD}}"

# Add any app-specific secrets here
# ...

# =============================================================================
# NETWORK CONFIGURATION
# =============================================================================
jail_network_cidr: "192.168.1.0/24"
jail_gateway: "192.168.1.1"
jail_interface: "em0"

# Jail IP addresses
jail_ip_database: "192.168.1.52"      # Pick next available even IP
jail_ip_<appname>: "192.168.1.53"     # Pick next available odd IP

# Application port
<appname>_port: 80  # Or your app's port

# =============================================================================
# SYSTEM CONFIGURATION
# =============================================================================
freebsd_version: "13.5-RELEASE"
freebsd_arch: "amd64"
zfs_pool: "zroot"
jail_dataset: "jails"

# =============================================================================
# BACKUP CONFIGURATION
# =============================================================================
backup_location: "/var/backups/<appname>"
backup_retention_days: 30
```

**Important**:
- Use `{{DB_PASSWORD}}` placeholder for database password
- Use `{{<APPNAME>_ADMIN_PASSWORD}}` for admin password
- Update IP addresses (check what's in use)
- Set correct application port

### Step 3: Update requirements.txt

Edit `requirements.txt` if you need specific Ansible modules:

```txt
ansible>=12.0.0
ansible-core>=2.19.0
# Add any additional Python dependencies
```

### Step 4: Update Inventory Template

Edit `inventory/hosts.yml` (if exists locally) or note the structure for CI/CD:

```yaml
---
all:
  children:
    jail_hosts:
      hosts:
        bsd-host:
          ansible_host: your.host.com
          ansible_user: root
          ansible_python_interpreter: /usr/local/bin/python3.11

    jails:
      children:
        database_jails:
          hosts:
            <appname>-db:
              jail_ip: 192.168.1.52
              jail_host: bsd-host
              jail_autostart: true
              jail_vnet: false

        app_jails:
          hosts:
            <appname>-app:
              jail_ip: 192.168.1.53
              jail_host: bsd-host
              jail_autostart: true
              jail_vnet: false
              jail_mounts:
                - { src: "/var/log/<appname>-jails/<appname>-app", dest: "/var/log/<appname>", options: "rw" }

    all_jails:
      children:
        database_jails:
        app_jails:
```

### Step 5: Customize prepare-host.yml

Edit `playbooks/prepare-host.yml`:

**Change**:
- ZFS dataset paths: `semaphore` → `<appname>`
- Dataset names in tasks

**Example**:
```yaml
- name: Create ZFS datasets for application data
  zfs:
    name: "{{ zfs_pool }}/{{ jail_dataset }}/data/<appname>/{{ item }}"
    state: present
    extra_zfs_properties:
      compression: lz4
      atime: off
  loop:
    - db
    - app
```

### Step 6: Customize deploy-db.yml

Edit `playbooks/deploy-db.yml`:

**Key changes**:
- Jail name: `semaphore-db` → `<appname>-db`
- Database name variables
- Data mount paths
- PostgreSQL configuration (pg_hba.conf)

**Mount point example**:
```yaml
- name: Configure jail mounts
  set_fact:
    jail_mounts:
      - src: "/{{ zfs_pool }}/{{ jail_dataset }}/data/<appname>/db"
        dest: "/var/db/postgres"
        options: "rw"
```

**Database creation**:
```yaml
- name: Create application database
  postgresql_db:
    name: "{{ <appname>_db_name }}"
    state: present
  become: yes
  become_user: postgres
```

### Step 7: Customize deploy-app.yml

Edit `playbooks/deploy-app.yml`:

**This requires the most customization** - application-specific installation:

```yaml
---
- name: Deploy <AppName> Application
  hosts: jail_hosts
  become: yes
  gather_facts: yes

  vars:
    jail_name: "<appname>-app"
    jail_ip: "{{ jail_ip_<appname> }}"
    jail_mounts:
      - src: "/{{ zfs_pool }}/{{ jail_dataset }}/data/<appname>/app"
        dest: "/var/<appname>"
        options: "rw"
      - src: "/var/log/<appname>-jails/<appname>-app"
        dest: "/var/log/<appname>"
        options: "rw"

  tasks:
    - name: Create application jail
      include_role:
        name: jail_create

    - name: Install <appname> packages
      shell: |
        jexec {{ jail_name }} pkg install -y \
          <package1> \
          <package2>

    - name: Configure <appname>
      template:
        src: templates/<appname>.conf.j2
        dest: /usr/local/jails/{{ jail_name }}/usr/local/etc/<appname>/<appname>.conf
      notify: restart <appname>

    - name: Initialize <appname>
      shell: |
        jexec {{ jail_name }} <appname>-setup \
          --db-host {{ jail_ip_database }} \
          --db-name {{ <appname>_db_name }} \
          --db-user {{ <appname>_db_user }} \
          --db-password {{ <appname>_db_password }}
      args:
        creates: /var/<appname>/.initialized

    - name: Enable and start <appname>
      shell: |
        jexec {{ jail_name }} sysrc <appname>_enable=YES
        jexec {{ jail_name }} service <appname> start

  handlers:
    - name: restart <appname>
      shell: jexec {{ jail_name }} service <appname> restart
```

**Customize**:
- Package names
- Configuration file paths
- Initialization commands
- Service names

### Step 8: Update backup.yml

Edit `playbooks/backup.yml`:

**Change**:
- Jail names
- Service names
- Database dump commands
- Backup paths

**Database dump example**:
```yaml
- name: Create database backup
  shell: |
    jexec <appname>-db su -l postgres -c \
      "pg_dump {{ <appname>_db_name }} > /var/db/postgres/<appname>_backup.sql"
```

### Step 9: Update restore.yml

Edit `playbooks/restore.yml`:

**Change**:
- Jail names
- Service names
- Restore paths
- Database restore commands

**Database restore example**:
```yaml
- name: Restore database
  shell: |
    jexec <appname>-db su -l postgres -c \
      "psql {{ <appname>_db_name }} < /var/db/postgres/<appname>_backup.sql"
```

### Step 10: Update Makefile

Edit `Makefile`:

```makefile
# Variables
ANSIBLE_PLAYBOOK := ansible-playbook
INVENTORY := -i inventory/hosts.yml

.PHONY: help deploy check backup restore snapshot destroy-all disaster-recovery

help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

deploy: ## Deploy complete <appname> infrastructure
	$(ANSIBLE_PLAYBOOK) $(INVENTORY) playbooks/site.yml

check: ## Verify deployment and connectivity
	$(ANSIBLE_PLAYBOOK) $(INVENTORY) -m ping jail_hosts

backup: ## Create backup of <appname> data
	$(ANSIBLE_PLAYBOOK) $(INVENTORY) playbooks/backup.yml

restore: ## Restore <appname> from backup (requires BACKUP_TIMESTAMP=YYYYMMDDTHHMMSS)
	@if [ -z "$(BACKUP_TIMESTAMP)" ]; then \
		echo "Error: BACKUP_TIMESTAMP required. Usage: make restore BACKUP_TIMESTAMP=20240101T120000"; \
		exit 1; \
	fi
	$(ANSIBLE_PLAYBOOK) $(INVENTORY) playbooks/restore.yml -e backup_timestamp=$(BACKUP_TIMESTAMP) -e confirm_restore=yes

snapshot: ## Create ZFS snapshots
	$(ANSIBLE_PLAYBOOK) $(INVENTORY) playbooks/snapshot.yml

destroy-all: ## Destroy all <appname> infrastructure (DANGEROUS!)
	$(ANSIBLE_PLAYBOOK) $(INVENTORY) playbooks/destroy-all.yml -e confirm_destroy_all=destroy-everything

disaster-recovery: ## Complete rebuild + restore (requires BACKUP_TIMESTAMP)
	$(ANSIBLE_PLAYBOOK) $(INVENTORY) playbooks/disaster-recovery.yml -e backup_timestamp=$(BACKUP_TIMESTAMP) -e confirm_disaster_recovery=yes
```

**Change**: Update help text references to your app.

### Step 11: Create Configuration Templates (if needed)

If your app needs config files, create `templates/` directory:

```bash
mkdir -p templates/
```

Example `templates/<appname>.conf.j2`:

```jinja
# {{ ansible_managed }}

[database]
host = {{ jail_ip_database }}
port = 5432
name = {{ <appname>_db_name }}
user = {{ <appname>_db_user }}
password = {{ <appname>_db_password }}

[server]
port = {{ <appname>_port }}
bind = 0.0.0.0

[admin]
user = {{ <appname>_admin_user }}
email = {{ <appname>_admin_email }}
```

### Step 12: Test Locally

```bash
cd <appname>/

# Create secrets.yml from template
cp group_vars/all/secrets.yml.template group_vars/all/secrets.yml
vim group_vars/all/secrets.yml  # Fill in actual values

# Test syntax
make check

# Deploy
make deploy

# Verify
ssh root@your-host
jls  # Should show <appname>-db and <appname>-app
jexec <appname>-app service <appname> status
```

---

## Playbook Customization

### Common Patterns

#### Installing Packages from Ports

```yaml
- name: Install from ports
  shell: |
    jexec {{ jail_name }} sh -c '
      cd /usr/ports/<category>/<app> &&
      make install clean BATCH=yes
    '
```

#### Downloading and Extracting

```yaml
- name: Download application
  get_url:
    url: "https://example.com/<app>.tar.gz"
    dest: "/tmp/<app>.tar.gz"

- name: Extract to jail
  unarchive:
    src: "/tmp/<app>.tar.gz"
    dest: "/usr/local/jails/{{ jail_name }}/opt/"
    remote_src: yes
```

#### Environment Variables

```yaml
- name: Set environment variables
  lineinfile:
    path: "/usr/local/jails/{{ jail_name }}/etc/rc.conf"
    regexp: "^{{ jail_name }}_env="
    line: '{{ jail_name }}_env="DB_HOST={{ jail_ip_database }} DB_PASS={{ <appname>_db_password }}"'
```

#### Init Scripts

```yaml
- name: Create init script
  template:
    src: templates/<appname>.sh.j2
    dest: "/usr/local/jails/{{ jail_name }}/usr/local/etc/rc.d/<appname>"
    mode: '0755'
```

---

## Testing Your Integration

### Manual Testing Checklist

- [ ] Playbooks pass syntax check (`ansible-playbook --syntax-check`)
- [ ] `make deploy` completes without errors
- [ ] Both jails are created (`jls`)
- [ ] Services are running (`jexec <appname>-app service <appname> status`)
- [ ] Port is listening (`sockstat -l | grep <port>`)
- [ ] Health endpoint responds (`curl http://<jail-ip>:<port>/<health-endpoint>`)
- [ ] Database connection works (check application logs)
- [ ] `make backup` creates backup directory
- [ ] `make restore` restores from backup successfully
- [ ] `make destroy-all` cleans up completely
- [ ] Disaster recovery works (`make disaster-recovery`)

### Automated Testing with CI/CD

After manual testing, integrate with GitHub Actions workflow.

---

## GitHub Secrets Configuration

### Required Secrets

Add these to GitHub repository settings (Settings → Secrets → Actions):

1. **Infrastructure** (same for all apps):
   - `SSH_PRIVATE_KEY` - SSH key for host access
   - `BSD_HOST` - Hostname/IP of FreeBSD host
   - `SSH_USER` - SSH username (typically `root`)

2. **Application-specific**:
   - `DB_PASSWORD` - Database password
   - `<APPNAME>_ADMIN_PASSWORD` - Admin password
   - `JAIL_IP_DATABASE` - Database jail IP (e.g., `192.168.1.52`)
   - `JAIL_IP_<APPNAME>` - Application jail IP (e.g., `192.168.1.53`)

**Note**: Secret names must match placeholders in `secrets.yml.template`.

### Update Workflow

Edit `.github/workflows/test-lifecycle.yml`:

1. Add your app to `APPS_JSON`:

```yaml
env:
  APPS_JSON: |
    [
      {
        "name": "semaphore",
        "working_dir": "semaphore",
        "jail_name": "semaphore-app",
        "port": 3000,
        "health_endpoint": "/api/ping",
        "service_name": "semaphore",
        "backup_location": "/var/backups/semaphore"
      },
      {
        "name": "<appname>",
        "working_dir": "<appname>",
        "jail_name": "<appname>-app",
        "port": 80,
        "health_endpoint": "/status",
        "service_name": "<appname>",
        "backup_location": "/var/backups/<appname>"
      }
    ]
```

2. Update secrets generation step if needed:

```yaml
- name: Create secrets.yml from template and GitHub Secrets
  run: |
    for app_dir in $(echo '${{ env.APPS_JSON }}' | jq -r '.[].working_dir'); do
      sed -e "s|{{DB_PASSWORD}}|${{ secrets.DB_PASSWORD }}|g" \
          -e "s|{{<APPNAME>_ADMIN_PASSWORD}}|${{ secrets.<APPNAME>_ADMIN_PASSWORD }}|g" \
          "$app_dir/group_vars/all/secrets.yml.template" > "$app_dir/group_vars/all/secrets.yml"
    done
```

3. Update inventory generation if new jails added.

That's it! The workflow automatically tests all apps.

---

## Example: Nextcloud

Complete example integrating Nextcloud.

### 1. Create Directory

```bash
cp -r semaphore/ nextcloud/
cd nextcloud/
```

### 2. secrets.yml.template

```yaml
---
# Database
postgres_admin_password: "{{DB_PASSWORD}}"
nextcloud_db_name: "nextcloud"
nextcloud_db_user: "nextcloud"
nextcloud_db_password: "{{DB_PASSWORD}}"

# Nextcloud admin
nextcloud_admin_user: "admin"
nextcloud_admin_password: "{{NEXTCLOUD_ADMIN_PASSWORD}}"

# Network
jail_ip_database: "192.168.1.52"
jail_ip_nextcloud: "192.168.1.53"
nextcloud_port: 80

# System
freebsd_version: "13.5-RELEASE"
zfs_pool: "zroot"
jail_dataset: "jails"

# Backup
backup_location: "/var/backups/nextcloud"
backup_retention_days: 30
```

### 3. deploy-app.yml (excerpt)

```yaml
- name: Install Nextcloud packages
  shell: |
    jexec nextcloud-app pkg install -y \
      nginx \
      php82 \
      php82-pgsql \
      php82-gd \
      php82-mbstring \
      nextcloud-php82

- name: Configure Nextcloud
  shell: |
    jexec nextcloud-app su -m www -c '
      cd /usr/local/www/nextcloud &&
      php occ maintenance:install \
        --database "pgsql" \
        --database-name "{{ nextcloud_db_name }}" \
        --database-host "{{ jail_ip_database }}" \
        --database-user "{{ nextcloud_db_user }}" \
        --database-pass "{{ nextcloud_db_password }}" \
        --admin-user "{{ nextcloud_admin_user }}" \
        --admin-pass "{{ nextcloud_admin_password }}" \
        --data-dir "/var/nextcloud"
    '
```

### 4. Workflow Integration

```yaml
{
  "name": "nextcloud",
  "working_dir": "nextcloud",
  "jail_name": "nextcloud-app",
  "port": 80,
  "health_endpoint": "/status.php",
  "service_name": "nginx",
  "backup_location": "/var/backups/nextcloud"
}
```

---

## Troubleshooting

### Jail Won't Start

**Check logs**:
```bash
tail -f /var/log/messages
jexec <appname>-app /bin/sh  # Try to enter jail manually
```

**Common issues**:
- Mount path doesn't exist
- ZFS dataset not created
- Duplicate IP address
- Missing packages in jail

### Database Connection Fails

**Verify**:
```bash
# From app jail
jexec <appname>-app psql -h 192.168.1.52 -U <appname> -d <appname>
```

**Check**:
- `pg_hba.conf` allows app jail IP
- PostgreSQL listening on jail IP (not just localhost)
- Correct password in secrets.yml
- Database exists

### Service Won't Start

**Debug**:
```bash
jexec <appname>-app service <appname> start
# Check rc.conf
jexec <appname>-app grep <appname> /etc/rc.conf
# Check service logs
jexec <appname>-app cat /var/log/<appname>/*.log
```

### Backup/Restore Issues

**Verify paths**:
```bash
# On host
ls -l /var/backups/<appname>/
# Check ZFS datasets
zfs list | grep <appname>
```

**Permissions**:
```bash
# Ensure backup directory exists and is writable
mkdir -p /var/backups/<appname>
chmod 755 /var/backups/<appname>
```

---

## Best Practices

1. **Test locally first** - Deploy to test host before CI/CD
2. **Small commits** - Test each playbook individually
3. **Document custom configs** - Add comments explaining non-obvious setups
4. **Use handlers** - For service restarts, config reloads
5. **Check idempotency** - Run playbooks twice, should not change anything
6. **Version pin** - Specify package versions where critical
7. **Health checks** - Always provide an API endpoint for validation
8. **Logging** - Mount logs to host for easy access

---

## Getting Help

- Check `ARCHITECTURE.md` for design principles
- Review `semaphore/` directory as reference implementation
- Read Ansible documentation for module usage
- Check FreeBSD Handbook for jail/ZFS details
- Test in development environment first

---

## Next Steps

After successful integration:

1. ✅ Commit your changes to Git
2. ✅ Update `.github/workflows/test-lifecycle.yml`
3. ✅ Add GitHub Secrets for your app
4. ✅ Trigger workflow and verify CI/CD passes
5. ✅ Document any app-specific quirks
6. ✅ Consider adding monitoring/alerting
