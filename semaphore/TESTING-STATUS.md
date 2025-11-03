# Testing Status

**Target Host:** pedrinhas.gabrielbelli.com
**Last Updated:** 2025-11-03
**Environment:** Production BSD host with FreeBSD jails

---

## ✅ Tested & Working

### Infrastructure
- [x] **SSH Connectivity** - Connection to BSD host via SSH key (~/.ssh/belli)
- [x] **Ansible Ping** - Basic Ansible connectivity test
- [x] **Python Interpreter** - Python 3.11 available on host

### Deployment
- [x] **Full Deployment** (`make deploy`) - 80 tasks completed successfully
  - Database jail created and configured
  - Semaphore jail created and configured
  - PostgreSQL 15 installed and configured
  - Semaphore 2.16.37 installed from GitHub (built-in TLS support)
  - TLS/HTTPS configuration working

### Application
- [x] **Semaphore Login** - Web UI accessible at https://192.168.1.51:3000
- [x] **Built-in TLS** - Self-signed certificates working correctly
- [x] **Session Management** - Cookie encryption with base64-encoded keys
- [x] **Database Connection** - PostgreSQL connectivity from Semaphore jail

### Operations
- [x] **ZFS Snapshots** (`make snapshot`) - ✅ **FULLY WORKING**
  - Creates instant snapshots of both jails
  - Output:
    ```
    zroot/jails/data/db@snapshot-20251103T120657
    zroot/jails/data/semaphore@snapshot-20251103T120657
    ```
  - Snapshot catalog logged to /var/log/semaphore-snapshots.log
  - Rollback instructions provided

- [x] **Database Backup** (`make backup`) - ✅ **FULLY WORKING**
  - PostgreSQL database dump: 108KB (0.11 MB)
  - Semaphore runtime configuration: 730B
  - Backup metadata file created
  - Location: /var/backups/semaphore/20251103T121642/
  - Files created:
    - database.dump (PostgreSQL custom format)
    - semaphore-data.tar.gz (config files)
    - backup-info.txt (metadata)
  - Old backups cleaned up (30 day retention)

- [x] **Database Restore** (`make restore`) - ✅ **FULLY WORKING**
  - Restored from backup: 20251103T121642
  - Database dropped and recreated
  - PostgreSQL dump restored successfully
  - Semaphore configuration restored
  - Service restarted automatically
  - Verification passed:
    - ✅ API responding (200 OK)
    - ✅ Database accessible (1 project, 1 user)
    - ✅ Service running (pid 80016)
  - Restore time: 16 seconds

### Utilities
- [x] **Secrets Generator** (`./scripts/generate-secrets.sh`)
  - Generates all base64-encoded secrets correctly
  - PostgreSQL passwords, admin credentials, encryption keys

---

## ❌ Not Yet Tested

### Deployment Playbooks
- [ ] **01-prepare-host.yml** - Host preparation (may have vars_files issue)
- [ ] **02-deploy-database.yml** - Database-only deployment
- [ ] **03-deploy-semaphore.yml** - Semaphore-only deployment
- [ ] **04-verify-deployment.yml** - Deployment verification
- [ ] **update-semaphore.yml** - Version update workflow

### Backup & Recovery
- [ ] **restore.yml** - Restore from backup
- [ ] **disaster-recovery.yml** - Complete rebuild from backup
- [ ] **Backup encryption** - Optional encryption feature
- [ ] **Backup retention** - Automatic old backup cleanup

### Destruction
- [ ] **destroy.yml** - Safe destruction (preserves data)
- [ ] **destroy-all.yml** - Complete destruction including data
  - Interactive confirmation required: type "destroy-everything"

### Monitoring & Logs
- [ ] **make status** - Check jail status
- [ ] **make logs-app** - View Semaphore logs
- [ ] **make logs-db** - View PostgreSQL logs
- [ ] **make shell-app** - Interactive shell in Semaphore jail
- [ ] **make shell-db** - Interactive shell in database jail

### Configuration
- [ ] **Custom CA certificates** - Import for LDAPS
- [ ] **Existing TLS certificates** - Use Let's Encrypt or custom certs
- [ ] **Multiple Semaphore instances** - Deploy additional jails
- [ ] **VNET networking** - Isolated network stack for jails

---

## 🐛 Known Issues

### Critical Issues
1. **group_vars not loaded for subdirectory playbooks**
   - **Impact:** All playbooks in `playbooks/` directory
   - **Root Cause:** Ansible looks for group_vars relative to playbook location
   - **Fix:** Add explicit `vars_files` to all playbooks:
     ```yaml
     vars_files:
       - ../group_vars/all/vars.yml
       - ../group_vars/all/secrets.yml
     ```
   - **Status:** Fixed in snapshot.yml and backup.yml
   - **Action Required:** Apply same fix to all other playbooks

2. **Jail filesystem paths not accessible from host** - ✅ **FIXED**
   - **Impact:** Backup playbook couldn't copy files from jail to host
   - **Root Cause:** Used incorrect paths (e.g., `/zroot/jails/data/db/` instead of `/zroot/jails/data/semaphore-db/`)
   - **Solution Applied:**
     - Create files in jail's `/tmp`
     - Access from host at `/zroot/jails/data/[jail-name]/tmp/`
     - Copy to backup directory on host
     - Clean up temporary files in jail
   - **Status:** ✅ Resolved - backup.yml now works fully

### Minor Issues
1. **Deprecation warning** - community.general.yaml callback
   - Impact: Warning messages in output
   - Can be disabled in ansible.cfg
   - Not blocking functionality

2. **Extended file attributes** - macOS quarantine attributes
   - Impact: None (already cleared)
   - Solution: `xattr -cr` applied to all files

---

## 🔧 Fixes Applied During Testing

### Configuration Fixes
1. ✅ SSH key configuration added to inventory
2. ✅ TLS configuration format updated (nested "tls" block)
3. ✅ Cookie encryption keys changed from hex to base64
4. ✅ web_host configuration added for session management
5. ✅ Semaphore user and group created
6. ✅ TLS certificate permissions fixed (semaphore:semaphore)

### Playbook Fixes
1. ✅ backup.yml - Added vars_files for variable loading
2. ✅ backup.yml - Fixed jail filesystem paths (semaphore-db, semaphore-app)
3. ✅ backup.yml - Fixed tar command syntax (shell: | instead of shell: >)
4. ✅ backup.yml - Added proper cleanup of temporary files
5. ✅ snapshot.yml - Added vars_files and removed invalid ZFS properties
6. ✅ restore.yml - Added vars_files for variable loading
7. ✅ restore.yml - Fixed jail filesystem paths (semaphore-db, semaphore-app)
8. ✅ restore.yml - Fixed YAML syntax (quoted task names with colons)
9. ✅ restore.yml - Fixed Jinja2 templates in debug messages
10. ✅ restore.yml - Added copy-extract-cleanup pattern for tar files
11. ✅ Created playbooks/README.md documenting group_vars issue

### Documentation
1. ✅ scripts/generate-secrets.sh - Helper for secret generation
2. ✅ README.md - Updated with secrets generator documentation
3. ✅ .gitignore - Enhanced for security (SSL keys, SSH keys, .claude/)

---

## 📋 Testing Checklist

### Priority 1 - Core Functionality
- [x] Deployment works end-to-end
- [x] Semaphore accessible via HTTPS
- [x] Login and authentication working
- [x] Snapshots create successfully
- [x] Backup creates and extracts successfully
- [x] Restore from backup works

### Priority 2 - Operations
- [ ] Update playbook works
- [ ] Destroy playbook works safely
- [ ] Logs accessible via make commands
- [ ] Shell access to jails works

### Priority 3 - Advanced Features
- [ ] Custom CA certificates import
- [ ] Existing TLS certificates
- [ ] Disaster recovery workflow
- [ ] Backup encryption

---

## 🎯 Next Steps

### Immediate (This Session)
1. ✅ Test snapshot functionality - **DONE**
2. ✅ Create testing status document - **DONE**
3. ✅ Fix backup playbook jail file path issue - **DONE**
4. ✅ Test backup playbook - **DONE**
5. ✅ Test restore playbook - **DONE**
6. ✅ Verify restored data - **DONE**

**Session Complete!** All core backup/restore functionality tested and working.

### Short Term
1. Apply vars_files fix to all remaining playbooks
2. Complete backup/restore testing
3. Test destruction workflows
4. Verify monitoring commands

### Long Term
1. Test advanced TLS configurations
2. Test CA certificate import
3. Test multiple instance deployment
4. Create automated test suite

---

## 📝 Notes

### Variable Loading Issue
**Critical Discovery:** Playbooks in subdirectories don't automatically load group_vars from parent directory. This affected ALL playbooks in `playbooks/` subdirectory. Solution documented in `playbooks/README.md`.

### Backup Strategy
Current approach uses "data-only" IaC philosophy:
- Infrastructure is code (recreate with `make deploy`)
- Only data needs backup (database, configs, certs)
- Snapshots provide instant rollback
- Full backups provide portability

### Testing Approach
- Testing on production host (pedrinhas.gabrielbelli.com)
- Each major component tested individually
- Issues documented and tracked
- Fixes applied incrementally
