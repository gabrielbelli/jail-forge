# jail-forge Roadmap

> Production-ready FreeBSD jail deployments with Ansible — battle-tested configurations for self-hosted applications with complete lifecycle management.

## Vision

**Problem:** Self-hosting applications on FreeBSD jails requires significant manual effort for each application: jail creation, networking, service configuration, TLS setup, database provisioning, backup procedures, and disaster recovery planning. There is no curated, standardised collection of deployment patterns that handles the full lifecycle.

**Value proposition:** jail-forge provides battle-tested, production-ready Ansible playbooks for deploying self-hosted applications in FreeBSD jails. Each application comes with complete lifecycle automation — deploy, backup, restore, snapshot, disaster recovery, and clean teardown — all following BSD conventions and verified through CI/CD testing. Users get Docker Compose-level convenience with FreeBSD jail-level security isolation.

## Target Audience

**Primary:** FreeBSD sysadmins and homelabbers who want to self-host applications in isolated FreeBSD jails with production-grade automation, backup, and disaster recovery.

**Secondary:**

- DevOps engineers managing FreeBSD infrastructure who need reproducible deployments
- Self-hosting enthusiasts migrating from Docker/Linux to FreeBSD jails
- Small business IT administrators running FreeBSD servers who need reliable application deployment

**User pain points:**

- Setting up FreeBSD jails manually is tedious, error-prone, and hard to reproduce
- No standardised patterns for jail lifecycle management (deploy, backup, restore, disaster recovery)
- Existing container/deployment tools (Docker, Kubernetes) are Linux-focused and don't work on FreeBSD
- Managing multiple self-hosted applications across jails without a common framework leads to inconsistency
- Backup and disaster recovery for jail-based services is often ad-hoc and unreliable
- Networking configuration (alias mode vs NAT vs VNET) for jails requires deep FreeBSD knowledge

**User goals:**

- Deploy self-hosted applications on FreeBSD with minimal manual configuration
- Have reliable, tested backup and disaster recovery procedures for every service
- Maintain infrastructure as code so everything can be rebuilt from scratch
- Isolate services in individual jails for security and maintainability
- Follow BSD conventions and best practices without needing to research them

**Usage context:** Used on FreeBSD servers (physical or VM) to deploy, manage, backup, and recover self-hosted applications. Typically run from a management workstation via SSH using Ansible, with Make targets for common operations. Used in homelab and small production environments.

## Current State (MVP)

### Existing Features

- Complete Semaphore deployment with PostgreSQL backend (production-ready)
- Shared jail-base role for reusable jail provisioning
- Three networking modes: IP alias (LAN), NAT with pf firewall, and VNET
- TLS/SSL support with self-signed certificates and custom CA import
- Full backup system with retention policies (count-based and age-based)
- ZFS snapshot support for instant rollback
- Disaster recovery workflow (destroy + rebuild + restore)
- Makefile-based operational shortcuts for all common tasks
- GitHub Actions CI/CD with comprehensive 12-phase lifecycle testing
- Idempotent deployments (safe to re-run)
- Version update playbook for Semaphore
- Ansible vault integration for secrets management
- Multi-jail architecture (separate app and database jails)
- Compressed backup archives (optional)
- Clean destroy operations (graceful and full teardown)
- Contributing guidelines with detailed standards for new applications

### Known Gaps

- Only one application (Semaphore) is implemented — 7 more are planned
- No reverse proxy / load balancer deployment (Traefik is planned)
- No identity provider / SSO integration (Authentik is planned)
- No centralised monitoring or alerting
- No centralised log aggregation
- No automated certificate management (Let's Encrypt / ACME)
- No inter-application orchestration (deploying multiple apps that depend on each other)
- No web UI or CLI tool for managing deployments — purely Makefile/ansible-playbook
- Shared roles only include jail-base — no shared database, web server, or monitoring roles

---

## Phase 1: Foundation & Infrastructure

> Resolve technical debt, extract shared roles, refactor CI for multi-app support, and deploy Traefik as the core reverse proxy — everything needed before scaling the application catalog.

### Milestone 1.1 — Clean Codebase & Shared Roles

Technical debt resolved, shared PostgreSQL role extracted, duplicate jail-base eliminated — codebase ready for multi-app development.

- [ ] Consolidate duplicate jail-base role (semaphore/roles/ vs shared/roles/)
- [ ] Extract shared PostgreSQL role from Semaphore-specific implementation
- [ ] Clean up backup-new.yml / backup.yml migration
- [ ] Generalise Semaphore-specific playbooks where applicable (test-vars.yml, secrets template)

### Milestone 1.2 — Multi-App CI Pipeline

CI/CD pipeline refactored to support any application with parameterised workflows and linting enforcement. New apps can be tested without CI changes.

- [ ] Refactor CI workflow from Semaphore-hardcoded to parameterised multi-app testing
- [ ] Add ansible-lint enforcement in CI pipeline
- [ ] Add yamllint enforcement in CI pipeline
- [ ] Ensure new applications can be added to CI without workflow changes

### Milestone 1.3 — Reverse Proxy & Production TLS

Traefik deployed as the central reverse proxy with automated Let's Encrypt certificates. Applications get production-grade TLS without self-signed certs.

- [ ] Deploy Traefik in a dedicated jail as the central reverse proxy
- [ ] Integrate Let's Encrypt / ACME for automated certificate management
- [ ] Configure Traefik auto-discovery or manual routing for jail-hosted applications
- [ ] Full lifecycle support for Traefik (backup, restore, disaster recovery)

---

## Phase 2: Core Application Catalogue

> Expand the application catalogue with the most demanded self-hosting applications — password management, Git hosting, and RSS reading — proving the multi-app architecture works.

### Milestone 2.1 — Second Production App (Vaultwarden)

Vaultwarden deployed with full lifecycle support, validating that the shared roles and multi-app CI pipeline work for a second application.

- [ ] Vaultwarden jail deployment with full configuration
- [ ] Database provisioning (SQLite or PostgreSQL)
- [ ] Backup / restore / disaster recovery lifecycle
- [ ] CI lifecycle testing for Vaultwarden
- [ ] Traefik integration for reverse proxying and TLS

### Milestone 2.2 — Four-App Catalogue

Gitea and Miniflux deployed, bringing the total to 4 production-ready applications. The application catalogue is credible and growing.

- [ ] Gitea deployment with PostgreSQL backend, full lifecycle support
- [ ] Miniflux deployment with PostgreSQL backend, full lifecycle support
- [ ] CI lifecycle testing for both new applications
- [ ] Traefik integration for both

### Milestone 2.3 — Community Contribution Ready

Application scaffolding tool available so community contributors can add new applications following standardised patterns with minimal friction.

- [ ] Scaffolding script or template to generate boilerplate for a new application
- [ ] Standardised directory structure and naming conventions documented
- [ ] Example walkthrough: adding a new application from scratch

---

## Phase 3: Identity, Collaboration & Operations

> Add complex flagship applications (Nextcloud, Authentik), centralised monitoring/logging, and inter-app orchestration — transforming jail-forge from individual app deployments into a cohesive self-hosting platform.

### Milestone 3.1 — Identity & File Sharing

Authentik SSO and Nextcloud deployed. Users can manage identity across all applications and have a full file sync/sharing solution.

- [ ] Authentik deployment with full lifecycle support
- [ ] SSO integration patterns for existing applications (Semaphore, Gitea, etc.)
- [ ] Nextcloud deployment with PostgreSQL backend and full lifecycle support
- [ ] MinIO or local storage backend for Nextcloud files

### Milestone 3.2 — Operational Visibility

Centralised monitoring and log aggregation deployed. Operators can monitor health and troubleshoot issues across all jails from a single dashboard.

- [ ] Monitoring stack deployment (Prometheus + Grafana or equivalent)
- [ ] Monitoring integration (Prometheus exporters, health endpoints)
- [ ] Centralised log aggregation
- [ ] Per-application health checks and alerting

### Milestone 3.3 — Stack Orchestration

Inter-application orchestration deployed. Users can deploy complete application stacks (e.g., Traefik + Authentik + Gitea) with a single command, like Docker Compose for FreeBSD.

- [ ] Dependency graph and automatic ordering for multi-app deployments
- [ ] Single-command stack deployment (e.g., `make deploy-stack STACK=devtools`)
- [ ] Stack-level backup and restore operations
- [ ] Documentation for defining custom stacks

---

## Phase 4: Advanced Features & Growth

> Add advanced networking, object storage, health intelligence, and performance optimisations — rounding out the platform for power users and larger deployments.

### Milestone 4.1 — Object Storage & Advanced Networking

MinIO deployed for S3-compatible storage and VNET networking refined for advanced network topologies.

- [ ] MinIO deployment with full lifecycle support
- [ ] S3-compatible storage integration for applications that support it (Nextcloud, Gitea)
- [ ] VNET networking refinements and documentation for advanced topologies

### Milestone 4.2 — Intelligent Operations

Application health monitoring with auto-restart and thin jail support for faster startup times. The platform manages itself intelligently.

- [ ] Application health monitoring with automatic restart and backoff
- [ ] Thin jail support for faster startup and reduced disk usage
- [ ] Lifecycle state tracking per jail (state machine)

---

## Competitive Landscape

See [COMPETITORS.md](COMPETITORS.md) for the full competitor analysis including detailed pain points, strengths, market gaps, and research sources.

---

## Planned Application Catalogue

| Application | Category | Status | Phase |
|---|---|---|---|
| Semaphore | CI/CD & Automation | Done | — |
| Traefik | Reverse Proxy / TLS | Planned | Phase 1 |
| Vaultwarden | Password Management | Planned | Phase 2 |
| Gitea | Git Hosting | Planned | Phase 2 |
| Miniflux | RSS Reader | Planned | Phase 2 |
| Authentik | Identity / SSO | Planned | Phase 3 |
| Nextcloud | File Sync & Sharing | Planned | Phase 3 |
| MinIO | Object Storage (S3) | Planned | Phase 4 |

---

## Success Metrics

- Number of production-ready application deployments in the catalogue
- GitHub stars and community adoption
- Community-contributed application deployments
- Successful disaster recovery completions (rebuild from backup works reliably)
- Time to deploy a new application from scratch (target: under 15 minutes)
- CI/CD lifecycle test pass rate across all applications

---

## Constraints

**Technical:**
- Requires FreeBSD 13.0+ — no Linux or macOS support for target hosts
- Requires ZFS filesystem — UFS is not supported
- Requires available static IP addresses for jail assignment
- Each new application requires significant Ansible playbook development
- Testing requires access to a real FreeBSD host (self-hosted GitHub Actions runner)

**Resources:**
- Solo developer project — limited development bandwidth
- Self-hosted CI runner needed for testing (FreeBSD not available on GitHub-hosted runners)
- Community contributions needed for expanding the application catalogue
