# TLS/HTTPS Setup Guide

This guide covers TLS certificate management for Ansible Semaphore on BSD jails.

## Overview

The deployment uses Nginx as a reverse proxy with TLS/HTTPS support. You have two options:

1. **Self-signed certificates** (automatic generation)
2. **Existing certificates** (bring your own)

All TLS configuration is centralized in `group_vars/all/secrets.yml`.

## Architecture

```
Internet (HTTPS/443)
    │
    ▼
[Nginx Jail - 192.168.1.52]
    │ TLS Termination
    │ Certificate: /usr/local/etc/ssl/
    │
    ▼ HTTP (internal)
[Semaphore Jail - 192.168.1.51:3000]
```

**Security:** Semaphore only listens on the internal jail network. External access is HTTPS-only through Nginx.

## Quick Start

### Option 1: Self-Signed Certificates (Default)

The easiest option - certificates are generated automatically during deployment.

**1. Configure in `group_vars/all/secrets.yml`:**

```yaml
# Use self-signed certificates
tls_cert_strategy: "generate"
tls_generate_selfsigned: true

# Certificate validity period (10 years default)
tls_cert_lifetime_days: 3650

# Certificate details
tls_cert_common_name: "semaphore.local"
tls_cert_organization: "My Organization"

# Subject Alternative Names (SANs)
tls_cert_san:
  - "DNS:semaphore.local"
  - "DNS:*.semaphore.local"
  - "IP:192.168.1.52"
```

**2. Deploy:**

```bash
ansible-playbook -i inventory/hosts.yml site.yml
```

**3. Access:**

```
https://192.168.1.52
```

**⚠️ Browser Warning:** Your browser will show a security warning because the certificate is self-signed. This is normal and expected. Click "Advanced" → "Proceed to site" to continue.

### Option 2: Existing Certificates (Recommended for Production)

Use certificates from your Certificate Authority (Let's Encrypt, corporate CA, etc.).

**1. Prepare your certificates on your control machine:**

```bash
# You should have:
/path/to/certs/
├── certificate.crt      # Your certificate
├── private.key          # Private key
└── ca-bundle.crt        # CA bundle (optional)
```

**2. Configure in `group_vars/all/secrets.yml`:**

```yaml
# Use existing certificates
tls_cert_strategy: "existing"

# Paths on your CONTROL machine (not the BSD host)
tls_existing_cert_path: "/path/to/certs/certificate.crt"
tls_existing_key_path: "/path/to/certs/private.key"
tls_existing_ca_path: "/path/to/certs/ca-bundle.crt"  # Optional
```

**3. Deploy:**

```bash
ansible-playbook -i inventory/hosts.yml site.yml
```

Ansible will copy your certificates to the nginx jail automatically.

## Configuration Reference

### All TLS Variables

Edit `group_vars/all/secrets.yml`:

```yaml
# =============================================================================
# TLS/SSL CERTIFICATE CONFIGURATION
# =============================================================================

# Certificate strategy: "generate" or "existing"
tls_cert_strategy: "generate"

# ----- Self-Signed Certificate Generation -----
tls_generate_selfsigned: true
tls_cert_lifetime_days: 3650  # 10 years
tls_cert_key_size: 4096       # RSA key size (2048, 3072, or 4096)

# Certificate Subject Details
tls_cert_country: "US"
tls_cert_state: "California"
tls_cert_locality: "San Francisco"
tls_cert_organization: "My Organization"
tls_cert_organizational_unit: "IT"
tls_cert_common_name: "semaphore.local"
tls_cert_email: "admin@example.com"

# Subject Alternative Names (SANs)
tls_cert_san:
  - "DNS:semaphore.local"
  - "DNS:*.semaphore.local"
  - "IP:192.168.1.52"

# ----- Existing Certificates -----
tls_existing_cert_path: "/path/to/certificate.crt"
tls_existing_key_path: "/path/to/private.key"
tls_existing_ca_path: "/path/to/ca-bundle.crt"  # Optional

# ----- Certificate Locations (on nginx jail) -----
tls_cert_dir: "/usr/local/etc/ssl"
tls_cert_file: "{{ tls_cert_dir }}/semaphore.crt"
tls_key_file: "{{ tls_cert_dir }}/semaphore.key"
tls_ca_file: "{{ tls_cert_dir }}/ca-bundle.crt"

# ----- Nginx SSL/TLS Settings -----
nginx_http_port: 80
nginx_https_port: 443
nginx_redirect_http_to_https: true

# SSL protocols (TLSv1.2 and TLSv1.3 recommended)
nginx_ssl_protocols: "TLSv1.2 TLSv1.3"

# Strong cipher suite
nginx_ssl_ciphers: "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384"
nginx_ssl_prefer_server_ciphers: true
nginx_ssl_session_cache: "shared:SSL:10m"
nginx_ssl_session_timeout: "10m"

# OCSP stapling (set true if using real certificates)
nginx_ssl_stapling: false

# Security Headers
nginx_security_headers:
  X-Frame-Options: "SAMEORIGIN"
  X-Content-Type-Options: "nosniff"
  X-XSS-Protection: "1; mode=block"
  Referrer-Policy: "strict-origin-when-cross-origin"
  Strict-Transport-Security: "max-age=31536000; includeSubDomains"
```

## Certificate Management

### Check Certificate Status

```bash
# SSH to BSD host
ssh root@YOUR_BSD_HOST

# View certificate details
jexec semaphore-nginx openssl x509 -in /usr/local/etc/ssl/semaphore.crt -text -noout

# Check expiration date
jexec semaphore-nginx openssl x509 -in /usr/local/etc/ssl/semaphore.crt -noout -dates

# Verify certificate and key match
jexec semaphore-nginx openssl x509 -noout -modulus -in /usr/local/etc/ssl/semaphore.crt | openssl md5
jexec semaphore-nginx openssl rsa -noout -modulus -in /usr/local/etc/ssl/semaphore.key | openssl md5
# (The MD5 hashes should match)
```

### Regenerate Self-Signed Certificate

If you need to regenerate the certificate (e.g., to extend validity or change SANs):

```bash
# Delete existing certificates
ssh root@YOUR_BSD_HOST
jexec semaphore-nginx rm -f /usr/local/etc/ssl/semaphore.crt /usr/local/etc/ssl/semaphore.key

# Redeploy nginx (will regenerate certs)
ansible-playbook -i inventory/hosts.yml playbooks/03-deploy-nginx.yml --tags nginx
```

### Replace with New Certificates

**Option A: Redeploy (recommended)**

1. Update certificate paths in `group_vars/all/secrets.yml`
2. Run: `ansible-playbook -i inventory/hosts.yml playbooks/03-deploy-nginx.yml`

**Option B: Manual replacement**

```bash
# Copy new certificates to jail
scp certificate.crt key.crt root@BSD_HOST:/tmp/

ssh root@BSD_HOST
jexec semaphore-nginx sh -c "
  cp /tmp/certificate.crt /usr/local/etc/ssl/semaphore.crt
  cp /tmp/key.crt /usr/local/etc/ssl/semaphore.key
  chmod 644 /usr/local/etc/ssl/semaphore.crt
  chmod 600 /usr/local/etc/ssl/semaphore.key
  service nginx reload
"
```

### Certificate Renewal (Let's Encrypt Example)

For Let's Encrypt certificates, set up automatic renewal:

**1. Create renewal script on control machine:**

```bash
#!/bin/bash
# renew-semaphore-certs.sh

# Renew Let's Encrypt certificate
certbot renew

# Copy to Ansible
cp /etc/letsencrypt/live/your-domain/fullchain.pem /path/to/ansible/certs/certificate.crt
cp /etc/letsencrypt/live/your-domain/privkey.pem /path/to/ansible/certs/private.key

# Deploy to BSD
cd /path/to/semaphore-ansible
ansible-playbook -i inventory/hosts.yml playbooks/03-deploy-nginx.yml --tags nginx
```

**2. Add to cron:**

```cron
0 3 * * 1 /path/to/renew-semaphore-certs.sh
```

## Using Let's Encrypt

To use Let's Encrypt certificates:

**Option 1: Obtain on control machine (recommended)**

```bash
# On your control machine (not BSD host)
certbot certonly --standalone -d your-domain.com

# Configure Ansible to use them
vim group_vars/all/secrets.yml
# Set:
tls_cert_strategy: "existing"
tls_existing_cert_path: "/etc/letsencrypt/live/your-domain.com/fullchain.pem"
tls_existing_key_path: "/etc/letsencrypt/live/your-domain.com/privkey.pem"

# Deploy
ansible-playbook -i inventory/hosts.yml site.yml
```

**Option 2: Certbot in jail (advanced)**

You can install certbot in the nginx jail and use the webroot plugin:

```bash
jexec semaphore-nginx pkg install py39-certbot

# Create webroot directory
jexec semaphore-nginx mkdir -p /usr/local/www/letsencrypt

# Configure nginx for ACME challenge (add to nginx config)
# location /.well-known/acme-challenge/ {
#     root /usr/local/www/letsencrypt;
# }

# Obtain certificate
jexec semaphore-nginx certbot certonly --webroot \
  -w /usr/local/www/letsencrypt \
  -d your-domain.com
```

## Security Best Practices

### 1. Protect Private Keys

```bash
# Private keys should be:
# - Permissions: 0600 (owner read/write only)
# - Owner: root
# - Never committed to git (add to .gitignore)
# - Encrypted at rest (use ansible-vault)
```

### 2. Use Strong Ciphers

Already configured in defaults. Modern TLS 1.2/1.3 with strong ciphers.

```yaml
nginx_ssl_protocols: "TLSv1.2 TLSv1.3"  # No SSLv3, TLSv1.0, TLSv1.1
nginx_ssl_ciphers: "ECDHE-..."  # Forward secrecy
```

### 3. Enable HSTS

Already enabled in security headers:

```yaml
Strict-Transport-Security: "max-age=31536000; includeSubDomains"
```

This forces browsers to always use HTTPS.

### 4. Monitor Expiration

Set up monitoring for certificate expiration:

```bash
#!/bin/bash
# check-cert-expiry.sh

DAYS_WARNING=30
CERT="/usr/local/etc/ssl/semaphore.crt"

# Get expiration date
EXPIRY=$(jexec semaphore-nginx openssl x509 -in $CERT -noout -enddate | cut -d= -f2)
EXPIRY_EPOCH=$(date -j -f "%b %d %T %Y %Z" "$EXPIRY" +%s)
NOW_EPOCH=$(date +%s)
DAYS_LEFT=$(( ($EXPIRY_EPOCH - $NOW_EPOCH) / 86400 ))

if [ $DAYS_LEFT -lt $DAYS_WARNING ]; then
    echo "WARNING: Certificate expires in $DAYS_LEFT days!"
    # Send alert
fi
```

### 5. Regular Backups

Certificates are included in `make backup`:

```bash
make backup
# Backs up: /usr/local/etc/ssl/ and /usr/local/etc/nginx/
```

## Troubleshooting

### Certificate Verification Failed

**Problem:** Browser shows "Certificate not trusted"

**Solution:**
- For self-signed: This is expected. Add exception in browser.
- For real certs: Ensure CA bundle is properly configured.

```bash
# Check certificate chain
jexec semaphore-nginx openssl s_client -connect localhost:443 -servername localhost
```

### Certificate and Key Mismatch

**Problem:** Nginx fails to start: "key values mismatch"

**Solution:** Verify cert and key match:

```bash
jexec semaphore-nginx openssl x509 -noout -modulus -in /usr/local/etc/ssl/semaphore.crt | openssl md5
jexec semaphore-nginx openssl rsa -noout -modulus -in /usr/local/etc/ssl/semaphore.key | openssl md5
# These should output the same hash
```

### HTTPS Not Accessible

**Problem:** Cannot access https://IP

**Solution:**

```bash
# Check nginx is running
jexec semaphore-nginx service nginx status

# Check nginx is listening on 443
jexec semaphore-nginx sockstat -l | grep 443

# Check firewall allows traffic
pfctl -sr | grep 443

# Test from BSD host
curl -k https://192.168.1.52/api/ping
```

### Weak Cipher Errors

**Problem:** "No ciphers available" or similar

**Solution:** Check OpenSSL version supports configured ciphers:

```bash
jexec semaphore-nginx openssl ciphers -v 'ECDHE-ECDSA-AES128-GCM-SHA256'
```

## Advanced Topics

### Custom Certificate Lifetime

```yaml
# Short-lived certificates (3 months)
tls_cert_lifetime_days: 90

# Long-lived (10 years)
tls_cert_lifetime_days: 3650
```

### Multiple Subject Alternative Names

```yaml
tls_cert_san:
  - "DNS:semaphore.example.com"
  - "DNS:semaphore.internal.local"
  - "DNS:ansible.example.com"
  - "IP:192.168.1.52"
  - "IP:10.0.0.100"
```

### Certificate Pinning

For enhanced security, pin the certificate in your applications:

```bash
# Get certificate fingerprint
jexec semaphore-nginx openssl x509 -in /usr/local/etc/ssl/semaphore.crt -noout -fingerprint -sha256
```

### Client Certificate Authentication

To require client certificates:

```nginx
# Add to nginx config
ssl_client_certificate /usr/local/etc/ssl/ca.crt;
ssl_verify_client on;
```

## References

- [Nginx SSL Module](https://nginx.org/en/docs/http/ngx_http_ssl_module.html)
- [Mozilla SSL Configuration Generator](https://ssl-config.mozilla.org/)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [OpenSSL Documentation](https://www.openssl.org/docs/)
- [SSL Labs Server Test](https://www.ssllabs.com/ssltest/)
