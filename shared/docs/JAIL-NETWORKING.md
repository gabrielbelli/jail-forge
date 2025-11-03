# FreeBSD Jail Networking Guide

## IP Alias vs VNET

### IP Alias Mode (Recommended)
- Jails share host's network stack
- Use IP aliases on host interface
- Simple, stable, production-proven
- Static IP addresses
- No NAT needed if on same network as host

### VNET Mode (Advanced)
- Jails get their own network stack
- Can use DHCP
- More complex setup
- Requires bridge configuration
- Use when need full network isolation or DHCP

## Static vs DHCP

### Static IPs (Recommended for Jails)
- Predictable, stable addresses
- Service discovery is simple
- Standard practice for jail deployments
- Example: database at 192.168.1.50, app at 192.168.1.51

### DHCP for Jails
- Requires VNET mode
- Need DNS or service discovery mechanism
- More complex to manage
- Consider DHCP reservations

## Common Patterns

See applications in this repository for working examples.
