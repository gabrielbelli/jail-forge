# Security Best Practices

## Secret Management

### Ansible Vault
Always encrypt sensitive data:
```bash
ansible-vault encrypt group_vars/all/secrets.yml
```

### Secret Generation
Use cryptographically secure random generation:
```bash
openssl rand -base64 32
```

## Network Security

### PF Firewall
- Use application-specific markers in pf.conf
- No NAT needed for IP alias mode
- Whitelist only required ports
- Example in application playbooks

### TLS/SSL
- Enable TLS by default
- Use strong ciphers
- Keep certificates up to date
- Support for self-signed or CA-signed certs

## Jail Security

### Service Isolation
- One service per jail
- Minimal jail capabilities
- No unnecessary privileges

### User Permissions
- Run services as non-root users
- Proper file permissions (0640 for configs)
- Group-based access control

## SSH Security

- Use SSH keys (not passwords)
- Disable root password login
- Use SSH ControlMaster for efficiency
- Keep SSH keys secure

## Monitoring

- Monitor failed login attempts
- Alert on unusual activity
- Log aggregation recommended
- Regular security audits

## Updates

- Keep FreeBSD updated
- Update jail base systems
- Monitor security advisories
- Test updates in staging first

## Backup Security

- Encrypt sensitive backups
- Secure backup storage
- Limit backup access
- Test restore procedures

See application-specific documentation for detailed security configurations.
