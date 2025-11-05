# GitHub Actions Testing Setup

This document explains how to set up and use the GitHub Actions workflow for testing jail-forge.

## Prerequisites

1. **Self-hosted GitHub runner** (Ubuntu) configured and connected to your repository
2. **SSH access** from the runner to your BSD host (configured in `inventory/hosts.yml`)
3. **GitHub Secrets** configured with your deployment secrets

## Setting Up GitHub Secrets

GitHub Secrets are encrypted environment variables that you can use in your workflows without exposing sensitive data.

### Step 1: Navigate to Repository Secrets

1. Go to your repository on GitHub: https://github.com/gabrielbelli/jail-forge
2. Click **Settings** (top menu)
3. In the left sidebar, expand **Secrets and variables**
4. Click **Actions**

### Step 2: Add Required Secrets

Click **"New repository secret"** for each of these **8 secrets**:

#### Application Secrets

**1. DB_PASSWORD**
- **Name**: `DB_PASSWORD`
- **Secret**: Your PostgreSQL database password
- Get from: `semaphore_db_password` in `group_vars/all/secrets.yml`

**2. SEMAPHORE_ADMIN_PASSWORD**
- **Name**: `SEMAPHORE_ADMIN_PASSWORD`
- **Secret**: Your Semaphore admin password
- Get from: `semaphore_admin_password` in `group_vars/all/secrets.yml`

**3. SEMAPHORE_ACCESS_KEY_ENCRYPTION**
- **Name**: `SEMAPHORE_ACCESS_KEY_ENCRYPTION`
- **Secret**: Your Semaphore encryption key
- Get from: `semaphore_access_key_encryption` in `group_vars/all/secrets.yml`

#### Infrastructure Secrets

**4. SSH_PRIVATE_KEY**
- **Name**: `SSH_PRIVATE_KEY`
- **Secret**: Your SSH private key (entire content)
- Get from: `cat ~/.ssh/belli` (or your SSH key path)
- Include the BEGIN and END lines

**5. BSD_HOST**
- **Name**: `BSD_HOST`
- **Secret**: Your BSD host hostname or IP
- Example: `pedrinhas.gabrielbelli.com`

**6. SSH_USER**
- **Name**: `SSH_USER`
- **Secret**: SSH username for BSD host
- Example: `root`

**7. JAIL_IP_DATABASE**
- **Name**: `JAIL_IP_DATABASE`
- **Secret**: IP address for database jail
- Example: `192.168.1.50`

**8. JAIL_IP_SEMAPHORE**
- **Name**: `JAIL_IP_SEMAPHORE`
- **Secret**: IP address for Semaphore jail
- Example: `192.168.1.51`

### Step 3: Get Secret Values

You can get the values from your existing `secrets.yml`:

```bash
cd semaphore
cat group_vars/all/secrets.yml
```

Copy each value and paste it into the corresponding GitHub Secret.

### Step 4: Verify All Secrets

After adding all secrets, verify you have all 8 (values will be hidden):
- ✓ BSD_HOST
- ✓ DB_PASSWORD
- ✓ JAIL_IP_DATABASE
- ✓ JAIL_IP_SEMAPHORE
- ✓ SEMAPHORE_ACCESS_KEY_ENCRYPTION
- ✓ SEMAPHORE_ADMIN_PASSWORD
- ✓ SSH_PRIVATE_KEY
- ✓ SSH_USER

## Running the Tests

### Manual Trigger (Current Setup)

1. Go to your repository on GitHub
2. Click the **Actions** tab
3. Select **"Test Full Lifecycle"** workflow from the left sidebar
4. Click **"Run workflow"** button (top right)
5. Choose options:
   - **Use workflow from**: `master` (or your branch)
   - **Skip destroy**: Check this if you want to leave the deployment running after tests
6. Click **"Run workflow"**

### What Gets Tested

The workflow performs a complete lifecycle test across **all configured applications**:

#### Phase 1: Environment Setup
- Installs Python, Ansible, and system dependencies
- Generates SSH keys and inventory files
- Creates secrets.yml from templates

#### Phase 2: Pre-flight Validation
1. ✓ **Syntax Check**: Validates all playbook syntax
2. ✓ **Connectivity**: Tests connection to BSD host

#### Phase 3: Application Deployment
3. ✓ **Deploy**: Full deployment for all apps (prepare-host → deploy-db → deploy-app)
4. ✓ **Health Check**: Service status, port listening, and API endpoint tests

#### Phase 4: Operational Testing
5. ✓ **Snapshot**: Creates ZFS snapshots
6. ✓ **Backup**: Creates backup archives
7. ✓ **Restore**: Restores from backups

#### Phase 5: Cleanup
8. ✓ **Cleanup**: Destroys all infrastructure (unless skip_destroy is checked)

### Monitoring Test Progress

1. After triggering the workflow, click on the running workflow in the Actions tab
2. Click on the **"Full Lifecycle Test"** job
3. Watch real-time logs for each step

### Test Duration

Expected runtime: ~5-10 minutes depending on your host performance

## Troubleshooting

### Secrets Not Working

**Symptom**: Workflow fails with "secrets.yml was not created" or authentication errors

**Solution**:
- Verify all three secrets are created in GitHub Settings → Secrets and variables → Actions
- Secret names must match exactly (case-sensitive): `DB_PASSWORD`, `SEMAPHORE_ADMIN_PASSWORD`, `SEMAPHORE_ACCESS_KEY_ENCRYPTION`
- Re-create secrets if needed

### Runner Not Picking Up Jobs

**Symptom**: Workflow stays in "Queued" state

**Solution**:
- Check your self-hosted runner status: Settings → Actions → Runners
- Ensure runner is "Idle" or "Active"
- Restart runner if needed

### SSH Connection Failures

**Symptom**: "Test connectivity to BSD host" step fails

**Solution**:
- Ensure runner has SSH access to BSD host
- Check `inventory/hosts.yml` configuration
- Verify SSH keys are properly configured on the runner

### Cleanup Verification Fails

**Symptom**: Final verification steps show jails still running

**Solution**:
- This is expected if you checked "Skip destroy"
- Otherwise, check BSD host manually: `jls`
- May need manual cleanup: `make destroy-all`

## Multi-Application Architecture

The workflow is **app-agnostic** and supports testing multiple applications simultaneously.

### Application Configuration

Applications are defined in the `APPS_JSON` environment variable in `.github/workflows/test-lifecycle.yml` (lines 22-33):

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
      }
    ]
```

### Adding New Applications

To add additional applications (e.g., Nextcloud, Jellyfin), simply add new entries to the JSON array:

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
        "name": "nextcloud",
        "working_dir": "nextcloud",
        "jail_name": "nextcloud-app",
        "port": 80,
        "health_endpoint": "/status.php",
        "service_name": "nginx",
        "backup_location": "/var/backups/nextcloud"
      }
    ]
```

### Configuration Fields

- **name**: Display name for the application
- **working_dir**: Directory containing the Ansible playbooks
- **jail_name**: Name of the application jail (for health checks)
- **port**: Primary service port to check
- **health_endpoint**: API endpoint to test (relative path)
- **service_name**: Service name in jail (for `service <name> status`)
- **backup_location**: Path to backup directory on BSD host

All workflow steps automatically iterate over the configured applications. No code changes needed!

## Future Enhancements

You can extend this workflow to:

- Run on pull requests (quick syntax check only)
- Run on every push to master (full lifecycle)
- Add notification on success/failure (Slack, Discord, email)
- Parallel testing on multiple BSD hosts
- Performance benchmarking
- Generate test reports

To enable automatic triggers, edit `.github/workflows/test-lifecycle.yml` and modify the `on:` section.
