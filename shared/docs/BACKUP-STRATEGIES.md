# Backup Strategies for jail-forge

## Infrastructure as Code Approach

jail-forge follows IaC principles: **infrastructure is disposable, data is precious**.

### What We Backup
- Database dumps
- Application configuration files
- User-generated content
- Custom certificates (optional)

### What We Don't Backup
- Jail base systems (reproducible from code)
- Installed packages (reproducible from code)
- Infrastructure configuration (in git)

## Retention Policies

### Time-Based Retention
Keep backups for X days:
```yaml
backup_retention_days: 30
```

### Count-Based Retention
Keep last N backups:
```yaml
backup_retention_count: 10
```

## ZFS Snapshots

For instant rollback capability:
```bash
make snapshot
```

Snapshots are fast and space-efficient but should complement, not replace, proper backups.

## Disaster Recovery

Complete rebuild from backup:
```bash
make disaster-recovery
```

This:
1. Deploys infrastructure from code
2. Restores data from backup
3. Verifies everything works

## Best Practices

1. **Automate backups**: Use cron
2. **Test restores**: Regularly verify backups work
3. **Off-site copies**: Copy backups to remote location
4. **Monitor**: Alert on backup failures
5. **Document**: Keep recovery procedures updated

## Example Cron Schedule

```cron
# Daily backups at 2 AM
0 2 * * * cd /path/to/app && make backup

# Weekly snapshots on Sunday at 3 AM
0 3 * * 0 cd /path/to/app && make snapshot
```

See application-specific documentation for detailed backup procedures.
