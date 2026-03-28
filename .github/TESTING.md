# GitHub Actions CI/CD

This repository uses GitHub Actions to test the full deployment lifecycle automatically.

## Setup GitHub Secrets

Go to **Settings → Secrets and variables → Actions** and add these secrets:

**Application Secrets:**
- `DB_PASSWORD` - PostgreSQL database password
- `SEMAPHORE_ADMIN_PASSWORD` - Semaphore admin password
- `SEMAPHORE_ACCESS_KEY_ENCRYPTION` - Semaphore encryption key

**Infrastructure Secrets:**
- `SSH_PRIVATE_KEY` - Your SSH private key (entire content)
- `BSD_HOST` - BSD host hostname or IP (e.g., `pedrinhas.gabrielbelli.com`)
- `SSH_USER` - SSH username (e.g., `root`)
- `JAIL_IP_DATABASE` - Database jail IP (e.g., `192.168.1.50`)
- `JAIL_IP_SEMAPHORE` - Semaphore jail IP (e.g., `192.168.1.51`)

Get values from your existing `group_vars/all/secrets.yml`.

## Running Tests

1. Go to **Actions** tab
2. Select **"Test Full Lifecycle"**
3. Click **"Run workflow"**
4. Optional: Check "Skip destroy" to leave deployment running

## What Gets Tested

The workflow tests the complete lifecycle:

1. **Syntax Check** - Validates all playbooks
2. **Connectivity** - Tests SSH to BSD host
3. **Deploy** - Full deployment (prepare-host → deploy-db → deploy-app)
4. **Health Check** - Service status, port listening, API endpoints
5. **Snapshot** - ZFS snapshots
6. **Backup** - Create backup archives
7. **Restore** - Restore from backups
8. **Cleanup** - Destroy all infrastructure (unless skipped)

## Adding New Applications

To add more applications to the workflow, edit `.github/workflows/test-lifecycle.yml` and add to the `APPS_JSON` array:

```yaml
{
  "name": "myapp",
  "working_dir": "myapp",
  "jail_name": "myapp-app",
  "port": 8080,
  "health_endpoint": "/health",
  "service_name": "myapp",
  "backup_location": "/var/backups/myapp"
}
```

That's it.
