# FreeBSD Jail Application Deployment - Project Template Guide

This guide provides a template for creating robust Ansible-based deployment projects for applications on FreeBSD jails, based on the patterns established in the semaphore-ansible project.

## Table of Contents
1. [Overview](#overview)
2. [Project Structure](#project-structure)
3. [Key Design Principles](#key-design-principles)
4. [Step-by-Step Setup Guide](#step-by-step-setup-guide)
5. [Configuration Patterns](#configuration-patterns)
6. [Operational Playbooks](#operational-playbooks)
7. [Common Pitfalls & Solutions](#common-pitfalls--solutions)
8. [Makefile Targets](#makefile-targets)
9. [Testing & Validation](#testing--validation)

---

## Overview

### What This Template Provides
- Infrastructure as Code (IaC) approach
- Multi-jail architecture for service isolation
- Complete lifecycle management (deploy, backup, restore, destroy)
- Disaster recovery capabilities
- BSD-compliant filesystem and service conventions
- Production-ready security patterns

### When to Use This Pattern
- Deploying multi-tier applications (app + database)
- Need for service isolation and security
- Requirement for backup/restore capabilities
- Production deployments requiring reproducibility
- Migration or disaster recovery scenarios

---

## Project Structure

```
your-app-ansible/
├── ansible.cfg                 # Ansible configuration (BSD-optimized)
├── site.yml                    # Main deployment orchestrator
├── Makefile                    # Operational shortcuts
├── inventory/
│   └── hosts.yml              # Target host and jail definitions
├── group_vars/
│   ├── all/
│   │   ├── vars.yml           # Global variables (version, ports, paths)
│   │   └── secrets.yml        # Encrypted secrets (Ansible Vault)
│   └── jail_hosts.yml         # Jail host specific variables
├── roles/
│   ├── jail-base/             # Base jail configuration
│   │   ├── tasks/
│   │   │   └── main.yml
│   │   ├── templates/
│   │   │   └── jail.conf.j2   # Jail configuration template
│   │   └── defaults/
│   │       └── main.yml
│   ├── database/              # Database jail role (if applicable)
│   │   ├── tasks/
│   │   ├── templates/
│   │   ├── handlers/
│   │   └── defaults/
│   └── your-app/              # Application jail role
│       ├── tasks/
│       │   ├── main.yml       # Main deployment tasks
│       │   ├── service.yml    # Service configuration
│       │   └── logs.yml       # Log management
│       ├── templates/
│       │   ├── rc.d.j2        # FreeBSD rc.d service script
│       │   ├── config.j2      # Application configuration
│       │   └── newsyslog.conf.j2  # Log rotation
│       ├── handlers/
│       │   └── main.yml       # Service restart handlers (use jexec!)
│       └── defaults/
│           └── main.yml       # Default variables
├── playbooks/
│   ├── 01-prepare-host.yml    # Host preparation (ZFS, networking, PF)
│   ├── 02-deploy-database.yml # Database jail deployment
│   ├── 03-deploy-app.yml      # Application jail deployment
│   ├── 04-verify-deployment.yml # Post-deployment verification
│   ├── backup.yml             # Data backup (IaC approach)
│   ├── restore.yml            # Data restoration
│   ├── disaster-recovery.yml  # Full rebuild + restore
│   ├── snapshot.yml           # ZFS snapshots
│   ├── destroy.yml            # Remove jails (keep data)
│   └── destroy-all.yml        # Remove everything (DANGEROUS)
└── docs/
    ├── architecture.md        # Architecture documentation
    ├── operations.md          # Operations runbook
    └── troubleshooting.md     # Common issues and solutions
```

---

## Key Design Principles

### 1. Infrastructure as Code (IaC)
- **Principle**: Infrastructure is disposable, data is precious
- **Implementation**:
  - Separate infrastructure playbooks from data operations
  - Backups contain only data, not configuration
  - Can rebuild entire infrastructure from code + data backup

### 2. Service Isolation via Jails
- **Principle**: One service per jail for security and maintainability
- **Implementation**:
  - Database in separate jail (e.g., `your-app-db`)
  - Application in separate jail (e.g., `your-app`)
  - Communication via IP addresses

### 3. IP Alias Mode (Not VNET)
- **Principle**: Static IPs for stability and simplicity
- **Implementation**:
  - Jails use IP aliases on host's interface
  - Static IP assignment for service discovery
  - No NAT needed - jails on same network as host

### 4. BSD Conventions
- **Principle**: Follow BSD standards for paths and services
- **Implementation**:
  - Use `/var/backups/your-app` not `/backups`
  - Use `/var/log/your-app` for logs
  - Use `/usr/local/etc/your-app` for configs
  - Use rc.d scripts for services

### 5. Nullfs for Shared Data
- **Principle**: Minimize data duplication, enable host-side access
- **Implementation**:
  - Mount host directories into jails with nullfs
  - Useful for logs (host can rotate), shared data
  - CRITICAL: Must clean up nullfs mounts in destroy playbooks

### 6. Handler Best Practices
- **Principle**: Service operations must run inside jails
- **Implementation**:
  - Always use `jexec {{ jail_name }} service ...`
  - Never use Ansible's service module directly for jailed services
  - Test handlers thoroughly

### 7. Idempotency
- **Principle**: Playbooks can be run multiple times safely
- **Implementation**:
  - Use `creates:` for download/extract tasks
  - Check state before destructive operations
  - Use Ansible's declarative modules

---

## Step-by-Step Setup Guide

### Phase 1: Project Initialization

#### 1. Create Project Structure
```bash
mkdir your-app-ansible
cd your-app-ansible

# Create directory structure
mkdir -p inventory group_vars/{all,jail_hosts} roles playbooks docs
mkdir -p roles/{jail-base,database,your-app}/{tasks,templates,handlers,defaults}
```

#### 2. Configure Ansible (`ansible.cfg`)
```ini
[defaults]
inventory = inventory/hosts.yml
roles_path = roles
host_key_checking = False
retry_files_enabled = False
gathering = smart
fact_caching = jsonfile
fact_caching_connection = /tmp/ansible_facts
fact_caching_timeout = 3600
stdout_callback = ansible.builtin.default
result_format = yaml
callbacks_enabled = profile_tasks, timer
interpreter_python = auto_silent
deprecation_warnings = True

# BSD-specific settings
timeout = 30
remote_user = root
become = False
become_user = root

[inventory]
enable_plugins = yaml, ini

[privilege_escalation]
become = False

[ssh_connection]
ssh_args = -o ControlMaster=auto -o ControlPersist=60s
pipelining = True
control_path = /tmp/ansible-ssh-%%h-%%p-%%r
```

#### 3. Define Inventory (`inventory/hosts.yml`)
```yaml
---
all:
  children:
    jail_hosts:
      hosts:
        your-bsd-host.example.com:
          ansible_host: 192.168.1.100
          ansible_user: root
          ansible_python_interpreter: /usr/local/bin/python3.9

          # Jail definitions
          jails:
            your-app-db:
              jail_ip: 192.168.1.50
              hostname: your-app-db.local

            your-app:
              jail_ip: 192.168.1.51
              hostname: your-app.local
```

#### 4. Define Variables (`group_vars/all/vars.yml`)
```yaml
---
# Application Configuration
app_name: your-app
app_version: v1.0.0
app_port: 8080
app_user: yourapp
app_group: yourapp

# Database Configuration (if applicable)
db_name: yourapp
db_user: yourapp
db_port: 5432

# Network Configuration
jail_interface: em0  # Change to your interface
jail_ip_database: 192.168.1.50
jail_ip_app: 192.168.1.51

# FreeBSD Configuration
freebsd_version: 14.1-RELEASE
freebsd_arch: amd64

# ZFS Configuration
zfs_pool: zroot
jail_dataset: jails

# Backup Configuration
backup_location: /var/backups/{{ app_name }}
backup_retention_count: 10

# Paths (BSD standard)
app_install_dir: /usr/local/bin
app_config_dir: /usr/local/etc/{{ app_name }}
app_data_dir: /var/db/{{ app_name }}
app_log_dir: /var/log/{{ app_name }}
custom_ca_dir: /usr/local/share/certs
```

#### 5. Define Secrets (`group_vars/all/secrets.yml`)
```yaml
---
# Database credentials
db_password: "changeme"
db_root_password: "changeme"

# Application secrets
app_secret_key: "changeme"
app_admin_password: "changeme"

# TLS Configuration (if applicable)
tls_cert_path: /usr/local/etc/ssl/cert.pem
tls_key_path: /usr/local/etc/ssl/key.pem
```

**IMPORTANT**: Encrypt with Ansible Vault:
```bash
ansible-vault encrypt group_vars/all/secrets.yml
```

---

### Phase 2: Host Preparation Playbook

Create `playbooks/01-prepare-host.yml`:

```yaml
---
# Prepare BSD host for jail deployment
- name: Prepare BSD Host for Jails
  hosts: jail_hosts
  gather_facts: true
  vars_files:
    - ../group_vars/all/secrets.yml
    - ../group_vars/all/vars.yml

  tasks:
    - name: Ensure ZFS is available
      command: zfs list
      register: zfs_check
      changed_when: false
      failed_when: zfs_check.rc != 0

    - name: Create ZFS datasets for jails
      community.general.zfs:
        name: "{{ item }}"
        state: present
        extra_zfs_properties:
          mountpoint: "/{{ item }}"
          compression: lz4
      loop:
        - "{{ zfs_pool }}/{{ jail_dataset }}"
        - "{{ zfs_pool }}/{{ jail_dataset }}/base"
        - "{{ zfs_pool }}/{{ jail_dataset }}/data"
        - "{{ zfs_pool }}/{{ jail_dataset }}/data/db"
        - "{{ zfs_pool }}/{{ jail_dataset }}/data/{{ app_name }}"

    - name: Create jail directories
      file:
        path: "{{ item }}"
        state: directory
        mode: '0755'
      loop:
        - /usr/local/etc/jail.conf.d
        - /var/log/jails

    - name: Download FreeBSD base for jails
      command: >
        fetch -o /tmp/base.txz
        https://download.freebsd.org/ftp/releases/{{ freebsd_arch }}/{{ freebsd_version }}/base.txz
      args:
        creates: /tmp/base.txz

    - name: Extract base system to ZFS dataset
      command: >
        tar -xf /tmp/base.txz -C /{{ zfs_pool }}/{{ jail_dataset }}/base
      args:
        creates: "/{{ zfs_pool }}/{{ jail_dataset }}/base/bin"

    - name: Update base system
      command: >
        freebsd-update -b /{{ zfs_pool }}/{{ jail_dataset }}/base
        --not-running-from-cron fetch install
      register: update_result
      changed_when: "'No updates' not in update_result.stdout"
      failed_when: false

    - name: Enable jail service in rc.conf
      lineinfile:
        path: /etc/rc.conf
        regexp: '^jail_enable='
        line: 'jail_enable="YES"'
        create: yes

    - name: Configure jail.conf
      template:
        src: ../roles/jail-base/templates/jail.conf.j2
        dest: /etc/jail.conf
        mode: '0644'

    # Optional: PF configuration for additional security
    - name: Ensure pf is configured for jail networking
      blockinfile:
        path: /etc/pf.conf
        create: yes
        marker: "# {mark} ANSIBLE MANAGED - {{ app_name }}"
        block: |
          # Filtering rules for {{ app_name }} jails (IP alias mode - no NAT needed)
          # Allow application web access
          pass in on {{ jail_interface }} proto tcp to {{ jail_ip_app }} port {{ app_port }}

          # Allow database access from app jail
          pass in on {{ jail_interface }} proto tcp from {{ jail_ip_app }} to {{ jail_ip_database }} port {{ db_port }}

          # Allow jails outbound access
          pass out on {{ jail_interface }} from { {{ jail_ip_database }}, {{ jail_ip_app }} }
      notify: reload pf
      when: configure_pf | default(false)

    - name: Enable pf in rc.conf
      lineinfile:
        path: /etc/rc.conf
        regexp: '^pf_enable='
        line: 'pf_enable="YES"'
        create: yes
      when: configure_pf | default(false)

  handlers:
    - name: reload pf
      command: pfctl -f /etc/pf.conf
```

---

### Phase 3: Jail Base Role

Create `roles/jail-base/templates/jail.conf.j2`:

```jinja2
# Global jail configuration
exec.start = "/bin/sh /etc/rc";
exec.stop = "/bin/sh /etc/rc.shutdown";
exec.clean;
mount.devfs;

# Allow raw sockets (needed for ping, traceroute)
allow.raw_sockets = 1;

# Path to jail base
path = "/{{ zfs_pool }}/{{ jail_dataset }}/base";

# Include all jail configs
.include "/usr/local/etc/jail.conf.d/*.conf";
```

Create `roles/jail-base/tasks/main.yml`:

```yaml
---
- name: Ensure jail configuration directory exists
  file:
    path: /usr/local/etc/jail.conf.d
    state: directory
    mode: '0755'

- name: Deploy jail configuration
  template:
    src: jail-specific.conf.j2
    dest: /usr/local/etc/jail.conf.d/{{ jail_name }}.conf
    mode: '0644'
  notify: restart jail

- name: Create jail-specific fstab
  template:
    src: fstab.j2
    dest: /etc/fstab.{{ jail_name }}
    mode: '0644'

- name: Create jail data directory
  file:
    path: "/{{ zfs_pool }}/{{ jail_dataset }}/data/{{ jail_name }}"
    state: directory
    mode: '0755'

- name: Start jail
  command: jail -c {{ jail_name }}
  register: jail_start
  changed_when: jail_start.rc == 0
  failed_when: false

- name: Verify jail is running
  command: jls -j {{ jail_name }}
  register: jail_verify
  changed_when: false
  failed_when: jail_verify.rc != 0
```

---

### Phase 4: Application Role Structure

#### Handler Pattern (`roles/your-app/handlers/main.yml`)
**CRITICAL**: Always use `jexec` for jailed services:

```yaml
---
# Handlers for your-app role
- name: restart your-app
  command: jexec {{ jail_name }} service {{ app_name }} restart
  listen: restart your-app

- name: reload your-app
  command: jexec {{ jail_name }} service {{ app_name }} reload
  listen: reload your-app
  ignore_errors: yes
```

#### RC Script Template (`roles/your-app/templates/rc.d.j2`)
```bash
#!/bin/sh

# PROVIDE: {{ app_name }}
# REQUIRE: DAEMON NETWORKING
# KEYWORD: shutdown

. /etc/rc.subr

name="{{ app_name }}"
rcvar="${name}_enable"
pidfile="/var/run/${name}.pid"
command="{{ app_install_dir }}/${name}"
command_args="{{ app_config_dir }}/config.yaml"

load_rc_config $name
: ${{{ app_name }}_enable:="NO"}
: ${{{ app_name }}_user:="{{ app_user }}"}
: ${{{ app_name }}_group:="{{ app_group }}"}

run_rc_command "$1"
```

#### Service Configuration (`roles/your-app/tasks/service.yml`)
```yaml
---
- name: Create rc.d service script
  template:
    src: rc.d.j2
    dest: /usr/local/etc/rc.d/{{ app_name }}
    mode: '0755'
  notify: restart your-app

- name: Enable service in rc.conf
  command: >
    jexec {{ jail_name }} sysrc {{ app_name }}_enable="YES"
  changed_when: true

- name: Start service
  command: jexec {{ jail_name }} service {{ app_name }} start
  register: service_start
  changed_when: service_start.rc == 0
  failed_when: false
```

#### Log Management (`roles/your-app/tasks/logs.yml`)
```yaml
---
- name: Create log directory on host
  file:
    path: "{{ app_log_dir }}"
    state: directory
    mode: '0755'

- name: Create log directory in jail
  command: jexec {{ jail_name }} mkdir -p {{ app_log_dir }}

- name: Configure newsyslog for log rotation
  template:
    src: newsyslog.conf.j2
    dest: /etc/newsyslog.conf.d/{{ app_name }}.conf
    mode: '0644'

- name: Create log rotation signal script
  template:
    src: logsignal.sh.j2
    dest: /usr/local/bin/{{ app_name }}-{{ jail_name }}-logsignal.sh
    mode: '0755'
```

#### Newsyslog Template (`roles/your-app/templates/newsyslog.conf.j2`)
```
# {{ app_name }} log rotation
{{ app_log_dir }}/{{ app_name }}.log    {{ app_user }}:{{ app_group }}    644  7   *   @T00  JC   /usr/local/bin/{{ app_name }}-{{ jail_name }}-logsignal.sh
```

#### Log Signal Script (`roles/your-app/templates/logsignal.sh.j2`)
```bash
#!/bin/sh
# Send SIGHUP to {{ app_name }} process in jail for log rotation
jexec {{ jail_name }} pkill -HUP -F /var/run/{{ app_name }}.pid
```

---

### Phase 5: Operational Playbooks

#### Backup Playbook (`playbooks/backup.yml`)
**Key Principle**: Backup only data, not infrastructure

```yaml
---
- name: Backup Application Data
  hosts: jail_hosts
  gather_facts: true
  vars_files:
    - ../group_vars/all/vars.yml
    - ../group_vars/all/secrets.yml
  vars:
    backup_timestamp: "{{ ansible_date_time.iso8601_basic_short }}"
    backup_dir: "{{ backup_location }}/{{ backup_timestamp }}"

  tasks:
    - name: Create backup directory
      file:
        path: "{{ backup_dir }}"
        state: directory
        mode: '0700'

    - name: Stop application service
      command: jexec {{ app_name }} service {{ app_name }} stop
      ignore_errors: yes

    - name: Backup database
      command: >
        jexec {{ app_name }}-db
        su - postgres -c "pg_dump -Fc {{ db_name }} -f /tmp/database.dump"
      when: database_enabled | default(true)

    - name: Copy database dump to host
      command: >
        cp /{{ zfs_pool }}/{{ jail_dataset }}/data/{{ app_name }}-db/tmp/database.dump
        {{ backup_dir }}/database.dump
      when: database_enabled | default(true)

    - name: Backup application configuration
      command: >
        jexec {{ app_name }}
        tar -czf /tmp/app-config.tar.gz -C {{ app_config_dir }} .

    - name: Copy config backup to host
      command: >
        cp /{{ zfs_pool }}/{{ jail_dataset }}/data/{{ app_name }}/tmp/app-config.tar.gz
        {{ backup_dir }}/app-config.tar.gz

    - name: Create backup info file
      copy:
        dest: "{{ backup_dir }}/backup-info.txt"
        content: |
          Backup Information
          ==================
          Application: {{ app_name }}
          Version: {{ app_version }}
          Timestamp: {{ backup_timestamp }}
          Host: {{ ansible_hostname }}

          Contents:
          - Database dump (PostgreSQL custom format)
          - Application configuration
        mode: '0600'

    - name: Start application service
      command: jexec {{ app_name }} service {{ app_name }} start

    - name: Clean up old backups
      shell: |
        cd {{ backup_location }}
        ls -t | tail -n +{{ backup_retention_count + 1 }} | xargs -r rm -rf
      when: backup_retention_count is defined
```

#### Snapshot Playbook (`playbooks/snapshot.yml`)
**Use Case**: Fast rollback capability using ZFS

```yaml
---
- name: Create ZFS Snapshots
  hosts: jail_hosts
  gather_facts: true
  vars:
    snapshot_name: "{{ ansible_date_time.iso8601_basic_short }}"

  tasks:
    - name: Create snapshot of database dataset
      community.general.zfs:
        name: "{{ zfs_pool }}/{{ jail_dataset }}/data/{{ app_name }}-db@{{ snapshot_name }}"
        state: present

    - name: Create snapshot of application dataset
      community.general.zfs:
        name: "{{ zfs_pool }}/{{ jail_dataset }}/data/{{ app_name }}@{{ snapshot_name }}"
        state: present

    - name: Display snapshot information
      debug:
        msg:
          - "✓ Snapshots created successfully!"
          - ""
          - "To rollback database:"
          - "  zfs rollback {{ zfs_pool }}/{{ jail_dataset }}/data/{{ app_name }}-db@{{ snapshot_name }}"
          - ""
          - "To rollback application:"
          - "  zfs rollback {{ zfs_pool }}/{{ jail_dataset }}/data/{{ app_name }}@{{ snapshot_name }}"
```

#### Destroy Playbook (`playbooks/destroy.yml`)
**CRITICAL**: Must clean up nullfs mounts!

```yaml
---
- name: Destroy Application Jails
  hosts: jail_hosts
  gather_facts: false
  vars_files:
    - ../group_vars/all/vars.yml

  vars_prompt:
    - name: confirm_destroy
      prompt: "⚠️  This will destroy all jails. Type 'yes' to confirm"
      private: no

  tasks:
    - name: Validate confirmation
      fail:
        msg: "Destroy cancelled"
      when: confirm_destroy != "yes"

    # CRITICAL: Stop services first
    - name: Stop application service
      command: jexec {{ app_name }} service {{ app_name }} stop
      ignore_errors: yes

    - name: Stop database service
      command: jexec {{ app_name }}-db service postgresql stop
      ignore_errors: yes
      when: database_enabled | default(true)

    - name: Wait for services to stop
      pause:
        seconds: 3

    # CRITICAL: Stop jails before unmounting
    - name: Stop application jail
      command: jail -r {{ app_name }}
      ignore_errors: yes

    - name: Stop database jail
      command: jail -r {{ app_name }}-db
      ignore_errors: yes
      when: database_enabled | default(true)

    - name: Wait for jails to stop
      pause:
        seconds: 2

    # CRITICAL: Clean up nullfs mounts
    - name: Check for remaining nullfs mounts
      shell: mount -t nullfs | grep -E "({{ app_name }})" || true
      register: remaining_mounts
      changed_when: false

    - name: Force unmount any remaining nullfs mounts
      shell: |
        mount -t nullfs | grep "{{ app_name }}" | awk '{print $3}' | xargs -r -n1 umount -f || true
      when: remaining_mounts.stdout != ""
      ignore_errors: yes

    # Clean up configuration
    - name: Remove jail configurations
      file:
        path: "{{ item }}"
        state: absent
      loop:
        - /usr/local/etc/jail.conf.d/{{ app_name }}.conf
        - /usr/local/etc/jail.conf.d/{{ app_name }}-db.conf
        - /etc/fstab.{{ app_name }}
        - /etc/fstab.{{ app_name }}-db

    - name: Display completion message
      debug:
        msg:
          - "✓ Jails destroyed successfully"
          - ""
          - "Data preserved in:"
          - "  {{ zfs_pool }}/{{ jail_dataset }}/data/{{ app_name }}"
          - "  {{ zfs_pool }}/{{ jail_dataset }}/data/{{ app_name }}-db"
          - ""
          - "To redeploy: make deploy"
```

---

### Phase 6: Main Site Orchestrator

Create `site.yml`:

```yaml
---
# Main deployment orchestrator
- name: Deploy Complete Application Stack
  hosts: localhost
  gather_facts: false
  tasks:
    - name: Display deployment plan
      debug:
        msg:
          - "==============================================="
          - "{{ app_name | upper }} Deployment"
          - "==============================================="
          - ""
          - "Phase 1: Prepare BSD host"
          - "Phase 2: Deploy database jail"
          - "Phase 3: Deploy application jail"
          - "Phase 4: Verify deployment"
          - ""
          - "Estimated time: 10-15 minutes"
          - "==============================================="

- import_playbook: playbooks/01-prepare-host.yml
- import_playbook: playbooks/02-deploy-database.yml
- import_playbook: playbooks/03-deploy-app.yml
- import_playbook: playbooks/04-verify-deployment.yml
```

---

### Phase 7: Makefile

Create a comprehensive `Makefile`:

```makefile
# Makefile for {{ app_name }} on BSD Jails
.PHONY: help deploy backup restore destroy check

ANSIBLE_PLAYBOOK := ansible-playbook
INVENTORY := inventory/hosts.yml

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo '🚀 Common Operations:'
	@echo '  deploy              Full deployment'
	@echo '  backup              Data backup'
	@echo '  restore             Restore from backup'
	@echo '  snapshot            ZFS snapshot'
	@echo '  verify              Verify deployment'
	@echo ''
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-20s %s\\n", $$1, $$2}' $(MAKEFILE_LIST)

check: ## Check connectivity to BSD host
	ansible -i $(INVENTORY) -m ping jail_hosts

deploy: ## Full deployment
	$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) site.yml

backup: ## Create data backup
	$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) playbooks/backup.yml

snapshot: ## Take ZFS snapshots
	$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) playbooks/snapshot.yml

restore: ## Restore from backup
	$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) playbooks/restore.yml

verify: ## Verify deployment
	$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) playbooks/04-verify-deployment.yml

destroy: ## Destroy jails (keep data)
	@echo "⚠️  WARNING: This will destroy all jails!"
	@read -p "Type 'yes' to continue: " confirm; \
	if [ "$$confirm" = "yes" ]; then \
		$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) playbooks/destroy.yml -e confirm_destroy=yes; \
	else \
		echo "Cancelled."; \
	fi

status: ## Show jail status
	ansible jail_hosts -i $(INVENTORY) -m shell -a "jls -v"

logs: ## Show application logs
	ansible jail_hosts -i $(INVENTORY) -m shell -a "tail -f {{ app_log_dir }}/{{ app_name }}.log"

shell: ## Open shell in application jail
	ansible jail_hosts -i $(INVENTORY) -m shell -a "jexec {{ app_name }} /bin/sh"

.DEFAULT_GOAL := help
```

---

## Configuration Patterns

### 1. Variable Precedence
Use this hierarchy:
1. `group_vars/all/vars.yml` - Global defaults
2. `group_vars/jail_hosts.yml` - Host-specific overrides
3. `roles/*/defaults/main.yml` - Role defaults
4. Command line: `-e variable=value`

### 2. Secret Management
Always use Ansible Vault:
```bash
# Encrypt secrets
ansible-vault encrypt group_vars/all/secrets.yml

# Edit encrypted file
ansible-vault edit group_vars/all/secrets.yml

# Run playbook with vault
ansible-playbook site.yml --ask-vault-pass
```

### 3. Jail Networking Patterns

**Pattern A: IP Alias (Recommended)**
```yaml
# In jail config
ip4.addr = "em0|192.168.1.50/24";
```
- Pros: Simple, stable, works out of the box
- Cons: Static IP management
- Use when: Standard deployments, production stability needed

**Pattern B: VNET (Advanced)**
```yaml
vnet;
vnet.interface = "epair0b";
```
- Pros: Full network stack, can use DHCP
- Cons: Complex, requires bridge setup
- Use when: Need DHCP, advanced networking required

### 4. Storage Patterns

**ZFS Dataset Layout**:
```
zroot/jails                    # Base jail dataset
├── base                       # Shared FreeBSD base
├── data                       # Jail-specific data
│   ├── app-db                 # Database data
│   └── app                    # Application data
```

**Nullfs Mounts** (use sparingly):
```
# Host path -> Jail path
/var/log/app -> /var/log/app (read/write, for host-side log rotation)
```

---

## Common Pitfalls & Solutions

### 1. Handler Execution in Jails
**Problem**: Service module tries to run on host, not in jail
```yaml
# ❌ WRONG - runs on host
- name: restart app
  service:
    name: myapp
    state: restarted
```

**Solution**: Always use jexec
```yaml
# ✅ CORRECT - runs in jail
- name: restart app
  command: jexec {{ jail_name }} service myapp restart
```

### 2. Orphaned Nullfs Mounts
**Problem**: Destroy fails, redeploy fails with "mount point busy"

**Solution**: Always clean up mounts in destroy playbook
```yaml
- name: Force unmount nullfs mounts
  shell: |
    mount -t nullfs | grep "myapp" | awk '{print $3}' | xargs -r -n1 umount -f || true
```

### 3. Variable Scope in Restore Playbooks
**Problem**: Variables from roles not available in standalone playbooks

**Solution**: Define required variables in playbook vars:
```yaml
vars:
  app_user: myapp
  app_config_dir: /usr/local/etc/myapp
```

### 4. PF Configuration Conflicts
**Problem**: Multiple applications modifying PF rules

**Solution**: Use application-specific markers
```yaml
marker: "# {mark} ANSIBLE MANAGED - {{ app_name }}"
```

### 5. Service Not Starting After Restore
**Problem**: Permissions wrong after restore

**Solution**: Always fix ownership/permissions after restore
```yaml
- name: Fix config ownership
  command: jexec {{ jail_name }} chown {{ app_user }}:{{ app_group }} {{ app_config_dir }}/config.json
```

---

## Testing & Validation

### Pre-deployment Checklist
- [ ] All variables defined in `group_vars/`
- [ ] Secrets encrypted with ansible-vault
- [ ] SSH access to BSD host works
- [ ] ZFS available on host
- [ ] FreeBSD version matches
- [ ] IP addresses don't conflict with DHCP range

### Deployment Testing
```bash
# 1. Check connectivity
make check

# 2. Syntax validation
ansible-playbook site.yml --syntax-check

# 3. Dry run (check mode)
ansible-playbook site.yml --check

# 4. Deploy
make deploy

# 5. Verify
make verify
```

### Backup/Restore Testing
```bash
# 1. Create backup
make backup

# 2. List backups
make list-backups

# 3. Test restore (on test environment!)
make restore
# Enter backup timestamp when prompted

# 4. Verify application works
curl -k https://192.168.1.51:8080/api/health
```

### Disaster Recovery Testing
```bash
# 1. Destroy everything
make destroy-all
# Type 'destroy-everything' to confirm

# 2. Run disaster recovery
make disaster-recovery
# Enter backup timestamp when prompted

# 3. Verify full stack
make verify
```

---

## Production Deployment Checklist

### Security Hardening
- [ ] Change all default passwords
- [ ] Enable TLS/SSL for web interfaces
- [ ] Configure firewall rules (PF)
- [ ] Disable password SSH (use keys only)
- [ ] Set up fail2ban or similar
- [ ] Review and minimize jail capabilities

### Operational Readiness
- [ ] Configure automated backups (cron)
- [ ] Set up monitoring (nagios, prometheus, etc.)
- [ ] Document disaster recovery procedures
- [ ] Test restore procedure
- [ ] Set up log aggregation
- [ ] Configure alerting

### Maintenance Schedule
```bash
# Daily
0 2 * * * cd /path/to/ansible && make backup

# Weekly
0 3 * * 0 cd /path/to/ansible && make snapshot

# Monthly
0 4 1 * * cd /path/to/ansible && ansible-playbook playbooks/update.yml
```

---

## Quick Reference Commands

### Jail Management
```bash
# List all jails
jls -v

# Execute command in jail
jexec <jail-name> <command>

# Open shell in jail
jexec <jail-name> /bin/sh

# Stop jail
jail -r <jail-name>

# Start jail
jail -c <jail-name>
```

### ZFS Management
```bash
# List datasets
zfs list

# Create snapshot
zfs snapshot zroot/jails/data/myapp@backup1

# Rollback to snapshot
zfs rollback zroot/jails/data/myapp@backup1

# List snapshots
zfs list -t snapshot
```

### Service Management (in jail)
```bash
# Start service
jexec myapp service myapp start

# Stop service
jexec myapp service myapp stop

# Restart service
jexec myapp service myapp restart

# Check status
jexec myapp service myapp status
```

---

## Example: Adapting for Different Applications

### Example 1: Nginx + PHP-FPM
```yaml
# In group_vars/all/vars.yml
app_name: web-stack
jails:
  web-nginx:
    jail_ip: 192.168.1.50
  web-php:
    jail_ip: 192.168.1.51

# Create separate roles for nginx and php-fpm
roles/
├── nginx/
└── php-fpm/
```

### Example 2: Gitea (Git + Database)
```yaml
app_name: gitea
gitea_version: 1.21.0
gitea_port: 3000
db_type: postgresql

jails:
  gitea-db:
    jail_ip: 192.168.1.60
  gitea-app:
    jail_ip: 192.168.1.61
```

### Example 3: MinIO (Object Storage)
```yaml
app_name: minio
minio_port: 9000
minio_console_port: 9001

# Single jail (no database needed)
jails:
  minio:
    jail_ip: 192.168.1.70
```

---

## Summary

This template provides a production-ready pattern for deploying applications on FreeBSD jails using Ansible. Key principles:

1. **Infrastructure as Code** - Everything reproducible from git repo
2. **Service Isolation** - One service per jail
3. **BSD Conventions** - Follow FreeBSD standards
4. **Operational Excellence** - Backup, restore, disaster recovery built-in
5. **Security First** - Vault for secrets, PF for firewall, TLS by default

Adapt this template to your specific application needs while maintaining these core principles.

---

## Additional Resources

- FreeBSD Handbook: https://docs.freebsd.org/en/books/handbook/
- Ansible Documentation: https://docs.ansible.com/
- ZFS Administration: https://docs.freebsd.org/en/books/handbook/zfs/
- PF Firewall: https://www.freebsd.org/doc/handbook/firewalls-pf.html

---

**Generated from**: semaphore-ansible project
**Last Updated**: 2025-11-03
**Template Version**: 1.0
