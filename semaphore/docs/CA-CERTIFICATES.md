# Custom CA Certificates Management

Guide for importing custom CA certificates into the Semaphore jail for LDAPS and other services with self-signed certificates.

## Overview

When using LDAPS (LDAP over SSL/TLS) with self-signed certificates, or connecting to any service with a custom CA, Semaphore needs to trust those certificates at the OS level.

This feature automatically imports your CA certificates into FreeBSD's system trust store.

## Use Cases

✅ **LDAPS with self-signed CA** - Most common use case
✅ **Private Git servers** with custom certificates
✅ **Internal APIs** using self-signed certs
✅ **Corporate CA** certificates
✅ **Any service** requiring custom CA trust

## Quick Start

### 1. Enable CA Import

Edit `group_vars/all/secrets.yml`:

```yaml
# Enable custom CA import
custom_ca_enabled: true

# Add your CA certificates
custom_ca_certificates:
  - path: "/path/to/ldap-ca.crt"
    name: "ldap-ca"
```

### 2. Prepare Your CA Certificate

Get your CA certificate from your LDAP server:

```bash
# Option 1: Export from LDAP server
# (On your LDAP server)
openssl s_client -connect ldap.example.com:636 -showcerts < /dev/null 2>/dev/null | \
  openssl x509 -outform PEM > ldap-ca.crt

# Option 2: If you already have the CA file
# Just use it directly
cp /path/to/your/ca-cert.crt ldap-ca.crt

# Verify it's a valid certificate
openssl x509 -in ldap-ca.crt -text -noout
```

### 3. Deploy

```bash
ansible-playbook -i inventory/hosts.yml site.yml
```

The CA certificate will be:
- Copied to `/usr/local/share/certs/` in the Semaphore jail
- Added to FreeBSD's system trust store
- Available for all SSL/TLS connections from Semaphore

## Configuration Reference

### In `group_vars/all/secrets.yml`

```yaml
# =============================================================================
# CUSTOM CA CERTIFICATES (for LDAPS, etc.)
# =============================================================================

# Enable/disable CA import
custom_ca_enabled: true

# List of CA certificates to import
custom_ca_certificates:
  - path: "/home/user/certs/ldap-ca.crt"      # Path on control machine
    name: "ldap-ca"                            # Name in jail (no extension)

  - path: "/home/user/certs/git-server-ca.crt"
    name: "git-ca"

  - path: "/home/user/certs/corporate-root-ca.crt"
    name: "corporate-root"

# CA directory in jail (default: /usr/local/share/certs)
custom_ca_dir: "/usr/local/share/certs"
```

### Parameters

| Variable | Default | Description |
|----------|---------|-------------|
| `custom_ca_enabled` | `false` | Enable/disable CA import |
| `custom_ca_certificates` | `[]` | List of CA certs to import |
| `custom_ca_dir` | `/usr/local/share/certs` | Where to store CAs in jail |

Each certificate in the list requires:
- **path**: Full path to CA cert on your control machine (where you run ansible)
- **name**: Friendly name for the cert (used for filename in jail)

## Example: LDAPS Setup

### Scenario
You have an Active Directory server with LDAPS on port 636 using a self-signed CA.

### Step 1: Get the CA Certificate

```bash
# From your workstation
openssl s_client -connect ad.company.local:636 -showcerts < /dev/null 2>/dev/null | \
  sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > ad-ca.crt

# Verify
openssl x509 -in ad-ca.crt -text -noout | grep -A2 "Subject:"
```

### Step 2: Configure Ansible

```yaml
# group_vars/all/secrets.yml

custom_ca_enabled: true

custom_ca_certificates:
  - path: "/home/admin/certs/ad-ca.crt"
    name: "ad-root-ca"
```

### Step 3: Deploy

```bash
ansible-playbook -i inventory/hosts.yml playbooks/03-deploy-semaphore.yml
```

### Step 4: Configure LDAP in Semaphore

In Semaphore UI → Settings → LDAP:

```
LDAP Server: ldaps://ad.company.local:636
```

The LDAPS connection will now work because the CA is trusted!

## How It Works

### Behind the Scenes

1. **Copy**: CA certs are copied from control machine to jail
2. **Install**: Placed in `/usr/local/share/certs/`
3. **Rehash**: `c_rehash` creates symbolic links with hash filenames
4. **Trust**: `certctl rehash` updates system trust store
5. **Verify**: OpenSSL and all apps now trust these CAs

### FreeBSD CA Trust Store

FreeBSD uses multiple locations for CA certificates:

- `/etc/ssl/cert.pem` - System bundle
- `/usr/local/share/certs/` - Custom CAs (where we install)
- `/usr/local/etc/ssl/certs/` - Linked by certctl

The `certctl` utility manages the trust store and creates the necessary symlinks.

## Verification

### Check if CA is Installed

```bash
# SSH to BSD host
ssh root@YOUR_BSD_HOST

# List certificates in jail
jexec semaphore-app ls -la /usr/local/share/certs/

# View certificate details
jexec semaphore-app openssl x509 -in /usr/local/share/certs/ldap-ca.crt -text -noout

# Test LDAPS connection
jexec semaphore-app openssl s_client -connect ldap.example.com:636 -CApath /usr/local/share/certs/
```

### Test LDAP Connection

```bash
# Install ldapsearch in jail
jexec semaphore-app pkg install openldap-client

# Test LDAPS
jexec semaphore-app ldapsearch -H ldaps://ad.company.local:636 \
  -D "CN=ServiceUser,CN=Users,DC=company,DC=local" \
  -w password \
  -b "DC=company,DC=local" \
  "(sAMAccountName=testuser)"
```

If it works without certificate errors, your CA is properly installed!

## Multiple CA Certificates

You can import multiple CA certificates:

```yaml
custom_ca_certificates:
  # LDAP server CA
  - path: "/home/admin/certs/ldap-ca.crt"
    name: "ldap-ca"

  # Git server CA
  - path: "/home/admin/certs/git-ca.crt"
    name: "git-ca"

  # Corporate root CA
  - path: "/home/admin/certs/corp-root.crt"
    name: "corp-root"

  # Corporate intermediate CA
  - path: "/home/admin/certs/corp-intermediate.crt"
    name: "corp-intermediate"
```

All will be imported and trusted.

## Updating CA Certificates

### To update existing CA:

```bash
# 1. Update the CA file on your control machine
cp new-ldap-ca.crt /home/admin/certs/ldap-ca.crt

# 2. Redeploy (will detect change and update)
ansible-playbook -i inventory/hosts.yml playbooks/03-deploy-semaphore.yml
```

### To add new CA:

```bash
# 1. Add to secrets.yml
vim group_vars/all/secrets.yml
# Add new entry to custom_ca_certificates list

# 2. Deploy
ansible-playbook -i inventory/hosts.yml playbooks/03-deploy-semaphore.yml
```

## Certificate Formats

### Supported Formats

- **PEM** (recommended) - Base64 encoded with headers
- **DER** - Binary format (convert to PEM first)
- **CER/CRT** - Usually PEM format

### Convert DER to PEM

```bash
openssl x509 -inform DER -in certificate.der -out certificate.pem
```

### Verify Format

```bash
# Check if it's PEM
head certificate.crt
# Should show: -----BEGIN CERTIFICATE-----

# Parse and verify
openssl x509 -in certificate.crt -text -noout
```

## Troubleshooting

### Certificate Not Trusted

**Problem**: LDAPS still fails with certificate error

**Solutions**:

```bash
# 1. Verify cert is in jail
jexec semaphore-app ls -la /usr/local/share/certs/

# 2. Check cert is valid
jexec semaphore-app openssl x509 -in /usr/local/share/certs/ldap-ca.crt -noout -text

# 3. Verify cert matches LDAP server
jexec semaphore-app openssl s_client -connect ldap.server:636 -CApath /usr/local/share/certs/

# 4. Manually rehash
jexec semaphore-app c_rehash /usr/local/share/certs/
jexec semaphore-app certctl rehash

# 5. Restart Semaphore
jexec semaphore-app service semaphore restart
```

### Wrong Certificate

**Problem**: Imported wrong CA

**Solution**:

```bash
# Remove from jail
jexec semaphore-app rm /usr/local/share/certs/wrong-ca.crt

# Rehash
jexec semaphore-app c_rehash /usr/local/share/certs/
jexec semaphore-app certctl rehash

# Update secrets.yml and redeploy
vim group_vars/all/secrets.yml
ansible-playbook -i inventory/hosts.yml playbooks/03-deploy-semaphore.yml
```

### Certificate Chain Issues

**Problem**: Need intermediate certificates too

**Solution**: Import the entire chain:

```yaml
custom_ca_certificates:
  - path: "/certs/root-ca.crt"
    name: "root-ca"
  - path: "/certs/intermediate-ca.crt"
    name: "intermediate-ca"
  - path: "/certs/ldap-server-ca.crt"
    name: "ldap-ca"
```

## Security Considerations

### 1. Protect CA Files

```bash
# CA certs should have restricted permissions
chmod 600 /path/to/ca-certificates/*.crt
```

### 2. Encrypt with Ansible Vault

For sensitive CA certificates:

```bash
# Encrypt the secrets file
ansible-vault encrypt group_vars/all/secrets.yml

# Deploy with vault
ansible-playbook -i inventory/hosts.yml site.yml --ask-vault-pass
```

### 3. Verify CA Authenticity

Always verify CA certificates before importing:

```bash
# Check issuer and subject
openssl x509 -in ca-cert.crt -noout -subject -issuer

# Verify fingerprint matches known good value
openssl x509 -in ca-cert.crt -noout -fingerprint -sha256
```

### 4. Regular Updates

- Update CA certificates when they expire
- Remove obsolete CAs
- Monitor expiration dates

```bash
# Check expiration
openssl x509 -in ca-cert.crt -noout -enddate
```

## Backup and Restore

### CA Certificates in Backups

CA certificates are automatically backed up with `make backup`:

```bash
# Backup (includes custom CAs)
make backup

# CAs are in the Semaphore config backup
# Location: /var/backups/semaphore/TIMESTAMP/semaphore-config.tar.gz
```

### Restore Process

```bash
# 1. Restore from ZFS snapshot
zfs rollback zroot/jails/data/semaphore@backup-TIMESTAMP

# 2. Or extract from backup
tar -xzf semaphore-config.tar.gz -C /
certctl rehash
```

## Advanced Usage

### Using Environment-Specific CAs

```yaml
# group_vars/production/secrets.yml
custom_ca_certificates:
  - path: "/certs/prod-ldap-ca.crt"
    name: "prod-ldap"

# group_vars/staging/secrets.yml
custom_ca_certificates:
  - path: "/certs/staging-ldap-ca.crt"
    name: "staging-ldap"
```

### Conditional CA Import

Only import if LDAP is enabled:

```yaml
custom_ca_enabled: "{{ semaphore_ldap_enabled | default(false) }}"
```

## References

- [FreeBSD certctl(8)](https://www.freebsd.org/cgi/man.cgi?certctl(8))
- [OpenSSL Certificate Commands](https://www.openssl.org/docs/man1.1.1/man1/x509.html)
- [LDAP over SSL/TLS](https://ldap.com/ldaps-vs-starttls/)
- [Semaphore LDAP Configuration](https://docs.ansible-semaphore.com/administration-guide/ldap)

## Summary

**To use LDAPS with self-signed CA:**

1. Get CA cert: `openssl s_client -connect ldap.server:636 -showcerts`
2. Enable in secrets.yml: `custom_ca_enabled: true`
3. Add cert path: `custom_ca_certificates: [{path: "...", name: "..."}]`
4. Deploy: `ansible-playbook site.yml`
5. Configure LDAP in Semaphore UI

Done! LDAPS will work with your self-signed CA.
