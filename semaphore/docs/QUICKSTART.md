# Quick Start Guide

Get Ansible Semaphore running on BSD jails in 5 minutes.

## Prerequisites Check

```bash
# On your FreeBSD host
freebsd-version  # Should be 13.0+
zfs list         # Should work
whoami           # Should be root or have root access
```

## Step-by-Step Deployment

### 1. Install Ansible on Control Machine

On your workstation (Linux/Mac):

```bash
# macOS
brew install ansible

# Linux
pip3 install ansible

# Install required collections
ansible-galaxy collection install community.general community.postgresql
```

### 2. Set Up Project

```bash
git clone <your-repo>
cd semaphore-ansible
```

### 3. Configure for Your Environment

Edit `inventory/hosts.yml`:

```yaml
jail_hosts:
  hosts:
    bsd-host:
      ansible_host: 10.0.0.100  # YOUR BSD HOST IP HERE
```

### 4. Test Connection

```bash
ansible -i inventory/hosts.yml jail_hosts -m ping
```

Expected output:
```
bsd-host | SUCCESS => {
    "ping": "pong"
}
```

### 5. Deploy Everything

```bash
ansible-playbook -i inventory/hosts.yml site.yml
```

This takes 5-10 minutes. You'll see:
- ✓ ZFS datasets created
- ✓ Jails created
- ✓ PostgreSQL installed
- ✓ Semaphore installed
- ✓ Services started

### 6. Access Semaphore

Open your browser:
```
http://192.168.1.51:3000
```

Login:
- **Username**: admin
- **Password**: changeme

### 7. Secure Your Installation

```bash
# SSH into Semaphore jail
ssh root@YOUR_BSD_HOST
jexec semaphore-app /bin/sh

# Change admin password via Semaphore UI
# Settings -> Users -> admin -> Change Password
```

## Verify Everything Works

```bash
# Check jails are running
ssh root@YOUR_BSD_HOST
jls

# Should show:
# JID  IP              Hostname
# 1    192.168.1.50    semaphore-db.local
# 2    192.168.1.51    semaphore-app.local
```

## Next Steps

- Read the [main README](../README.md) for full documentation
- Configure your first Ansible project in Semaphore
- Set up backups with `make backup`
- Explore the Makefile commands with `make help`

## Troubleshooting

### Can't connect to BSD host
```bash
# Test SSH manually
ssh root@YOUR_BSD_HOST

# Check SSH is running on BSD host
service sshd status
```

### Jails not accessible
```bash
# Check pf is running and configured
pfctl -sr

# Ensure NAT is enabled
sysrc pf_enable=YES
service pf start
```

### Semaphore won't start
```bash
# Check logs
ssh root@YOUR_BSD_HOST
jexec semaphore-app tail -f /var/log/semaphore/semaphore.log
```

### Database connection failed
```bash
# Test from Semaphore jail
jexec semaphore-app nc -zv 192.168.1.50 5432

# If fails, check PostgreSQL
jexec semaphore-db service postgresql status
```

## Need Help?

- Check the [main README](../README.md)
- Review [operations guide](operations.md)
- Open a GitHub issue
