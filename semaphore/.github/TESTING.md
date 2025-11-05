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

Click **"New repository secret"** for each of these:

#### Secret 1: `DB_PASSWORD`
- **Name**: `DB_PASSWORD`
- **Secret**: Your PostgreSQL database password
- Example: The value from `db_password` in your local `group_vars/all/secrets.yml`

#### Secret 2: `SEMAPHORE_ADMIN_PASSWORD`
- **Name**: `SEMAPHORE_ADMIN_PASSWORD`
- **Secret**: Your Semaphore admin password
- Example: The value from `semaphore_admin_password` in your local `group_vars/all/secrets.yml`

#### Secret 3: `SEMAPHORE_ACCESS_KEY_ENCRYPTION`
- **Name**: `SEMAPHORE_ACCESS_KEY_ENCRYPTION`
- **Secret**: Your Semaphore encryption key
- Example: The value from `semaphore_access_key_encryption` in your local `group_vars/all/secrets.yml`

### Step 3: Get Secret Values

You can get the values from your existing `secrets.yml`:

```bash
cd semaphore
cat group_vars/all/secrets.yml
```

Copy each value and paste it into the corresponding GitHub Secret.

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

The workflow performs a complete lifecycle test:

1. ✓ **Syntax Check**: Validates all playbook syntax
2. ✓ **Connectivity**: Tests connection to BSD host
3. ✓ **Deploy**: Full deployment (prepare-host → deploy-db → deploy-app)
4. ✓ **Snapshot**: Creates ZFS snapshots
5. ✓ **Backup**: Creates backup archive
6. ✓ **Restore**: Restores from the backup
7. ✓ **Cleanup**: Destroys all (unless skip_destroy is checked)

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

## Future Enhancements

You can extend this workflow to:

- Run on pull requests (quick syntax check only)
- Run on every push to master (full lifecycle)
- Add notification on success/failure (Slack, Discord, email)
- Parallel testing on multiple BSD hosts
- Performance benchmarking
- Generate test reports

To enable automatic triggers, edit `.github/workflows/test-lifecycle.yml` and modify the `on:` section.
