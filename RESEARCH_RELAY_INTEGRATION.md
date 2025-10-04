# Research Relay Integration Summary

**Status**: ✅ Complete - Ready for deployment
**Date**: 2025-10-04
**Flake**: `goodlab` (flake-parts + services-flake architecture)

## What Was Integrated

A complete self-hosted, crypto-only peptide commerce platform using:
- **noir** host: Odoo ERP/eCommerce + PostgreSQL + PDF-intake service
- **zinc** host: BTCPay Server payment gateway

All services are declaratively configured using NixOS modules and integrated into your existing `goodlab` flake.

## Architecture

```
                    Cloudflare
                (DNS + WAF + Origin Certs)
                         │
           ┌─────────────┴─────────────┐
           │                           │
        ┌──▼────┐                 ┌────▼───┐
        │ noir  │                 │  zinc  │
        └───────┘                 └────────┘
    Odoo + PostgreSQL          BTCPay Server
    PDF-intake + Redis         + Bitcoin Node
```

## Files Created

### Service Modules (`services/research-relay/`)

1. **`_common-hardening.nix`** (106 lines)
   - fail2ban for SSH protection
   - nftables firewall configuration
   - Nginx security headers (HSTS, CSP, X-Frame-Options)
   - Kernel hardening via sysctl
   - Rate limiting rules

2. **`odoo.nix`** (216 lines)
   - Odoo Community Edition service
   - PostgreSQL 16 database
   - Nginx reverse proxy with Cloudflare origin certs
   - US-only checkout enforcement
   - Nightly encrypted backups (30-day retention)
   - Age gate + session cookie support

3. **`btcpay.nix`** (248 lines)
   - BTCPay Server Docker Compose stack
   - NBXplorer + Bitcoin Core + PostgreSQL
   - Nginx reverse proxy for `pay.research-relay.com`
   - Encrypted backups with age (60-day retention)
   - Bitcoin P2P port (8333) exposed

4. **`pdf-intake.nix`** (186 lines)
   - FastAPI service for vendor PDF processing
   - Celery worker with Redis broker
   - Odoo XML-RPC integration
   - Token-based authentication
   - Internal-only (localhost:8071)

5. **`secrets.nix`** (95 lines)
   - sops-nix secret definitions
   - Conditional loading based on enabled services
   - Proper ownership and permissions

### Documentation

6. **`README.md`** - Complete architecture documentation
7. **`QUICKSTART.md`** - Step-by-step deployment guide
8. **`secrets.yaml.example`** - Secrets template
9. **`.sops.yaml.example`** - SOPS configuration

### CI/CD

10. **`.github/workflows/research-relay-ci.yml.example`**
    - Flake validation
    - OCI image builds (Odoo + PDF-intake)
    - GHCR push (ghcr.io/scientific-oops)
    - Optional SSH deployment

### Machine Configurations

11. **`machines/noir/configuration.nix`** - Updated with:
    ```nix
    services.researchRelay = {
      odoo.enable = true;
      pdfIntake.enable = true;
    };
    ```

12. **`machines/zinc/configuration.nix`** - Updated with:
    ```nix
    services.researchRelay = {
      btcpay.enable = true;
    };
    ```

### Flake Integration

13. **`flake.nix`** - Added to `perSystem.packages`:
    - `odooImage` - Odoo OCI container
    - `pdfIntakeImage` - PDF-intake OCI container

## How to Deploy

### Prerequisites

1. **Generate secrets** (see `QUICKSTART.md`):
   ```bash
   # Age key for backups
   age-keygen -o backup.key

   # API tokens
   openssl rand -hex 32  # PDF-intake
   openssl rand -hex 32  # BTCPay webhook
   ```

2. **Configure Cloudflare**:
   - Obtain origin certificates
   - Setup DNS records (research-relay.com, www, pay)
   - Create WAF rule for US-only checkout

3. **Create secrets file**:
   ```bash
   cp services/research-relay/secrets.yaml.example secrets/research-relay.yaml
   # Edit and encrypt with sops
   sops -e -i secrets/research-relay.yaml
   ```

### Deployment Commands

```bash
# Validate configuration
nix flake check

# Build and deploy to noir
sudo nixos-rebuild switch --flake .#noir

# Build and deploy to zinc
sudo nixos-rebuild switch --flake .#zinc

# Build OCI images for GHCR
nix build .#packages.x86_64-linux.odooImage
nix build .#packages.x86_64-linux.pdfIntakeImage
```

### Post-Deployment Setup

1. **Odoo** (`https://research-relay.com`):
   - Create database
   - Install eCommerce modules
   - Configure BTCPay payment provider

2. **BTCPay** (`https://pay.research-relay.com`):
   - Create admin account
   - Setup Bitcoin wallet
   - Generate API key for Odoo
   - Configure webhook to Odoo

3. **PDF-Intake**:
   - Create Odoo service account
   - Test API with curl

## Service Integration Points

### Odoo ↔ BTCPay
- Odoo creates invoice via BTCPay API
- BTCPay posts webhook to Odoo on payment
- Webhook signature validation with shared secret

### Odoo ↔ PDF-Intake
- PDF-Intake calls Odoo XML-RPC for price updates
- Service account authentication
- Manual review workflow before commit

## Security Features

✅ SSH key-only authentication (no passwords)
✅ fail2ban brute-force protection
✅ nftables firewall (ports 22, 80, 443)
✅ Nginx security headers (HSTS, CSP, X-Frame-Options)
✅ Rate limiting (10 req/s general, 30 req/s API)
✅ Cloudflare WAF for US-only checkout
✅ Encrypted backups with age
✅ Separate hosts for services (isolation)
✅ Kernel hardening via sysctl
✅ Service user isolation (odoo, pdf-intake)
✅ Systemd service hardening (PrivateTmp, ProtectSystem)

## Backup Strategy

### Odoo (noir)
- **Frequency**: Nightly
- **Retention**: 30 days
- **Method**: pg_dump → gzip
- **Location**: `/var/backups/research-relay/`

### BTCPay (zinc)
- **Frequency**: Nightly
- **Retention**: 60 days (financial records)
- **Method**: tar + age encryption
- **Includes**: Wallet seeds, store config, PostgreSQL

### Restore Testing
Monthly restore verification required for compliance.

## Monitoring

Current: systemd status + journald logs

Future (optional):
- Prometheus metrics
- Loki log aggregation
- Grafana dashboards

## Module Options

All services are disabled by default. Enable with:

```nix
services.researchRelay = {
  odoo.enable = true;          # Odoo eCommerce (noir)
  pdfIntake.enable = true;     # PDF parser (noir)
  btcpay.enable = true;        # Payment gateway (zinc)
};
```

## Verification

After deployment, verify services:

```bash
# noir services
systemctl status odoo
systemctl status pdf-intake-api
systemctl status pdf-intake-worker
systemctl status postgresql
systemctl status redis-pdf-intake

# zinc services
systemctl status btcpay
docker ps
systemctl status nginx

# Check backups
ls -lah /var/backups/research-relay/

# Check timers
systemctl list-timers | grep -E 'odoo|btcpay'
```

## Next Steps

1. ✅ Services integrated into flake
2. ✅ Documentation complete
3. ⏭️ Configure Cloudflare (DNS + origin certs + WAF)
4. ⏭️ Create and encrypt secrets file
5. ⏭️ Deploy to noir and zinc
6. ⏭️ Complete post-deployment configuration
7. ⏭️ Test end-to-end checkout flow
8. ⏭️ Setup monitoring (optional)
9. ⏭️ Configure GitHub Actions CI/CD

## References

- **Architecture Doc**: `services/research-relay/README.md`
- **Deployment Guide**: `services/research-relay/QUICKSTART.md`
- **Original Spec**: (Research Relay architecture document)
- **Service Modules**: `services/research-relay/*.nix`

## Support

For issues or questions:
- **Email**: scientific-ops@research-relay.com
- **Repository**: scientific-oops/research-relay (to be created)
- **Domain**: research-relay.com (Cloudflare managed)

---

**Integration completed successfully!** All Research Relay services are now declaratively managed via NixOS modules in your `goodlab` flake.
