# Research Relay Service Architecture

Self-hosted, crypto-only peptide commerce platform built with NixOS.

## Architecture Overview

```
┌─────────────────────────────────────────────────┐
│                  Cloudflare                     │
│   (DNS, WAF, Origin Certs, US-only checkout)   │
└─────────────────┬───────────────────────────────┘
                  │
        ┌─────────┴──────────┐
        │                    │
    ┌───▼────┐          ┌────▼────┐
    │  noir  │          │  zinc   │
    └────────┘          └─────────┘
```

### Host: noir (Primary Application Server)

- **Odoo Community Edition** - ERP/eCommerce platform
- **PostgreSQL 16** - Database backend
- **PDF-Intake Service** - Vendor price sheet processing (FastAPI + Celery + Redis)
- **nginx** - Reverse proxy with Cloudflare origin certs

### Host: zinc (Payment Gateway)

- **BTCPay Server** - Bitcoin/Lightning payment processing
- **PostgreSQL** - BTCPay database
- **NBXplorer** - Bitcoin blockchain indexer
- **Bitcoin Core** - Full node
- **nginx** - Reverse proxy for pay.research-relay.com

## Service Modules

All modules located in `services/research-relay/`:

| Module                  | Purpose                                                 | Host |
| ----------------------- | ------------------------------------------------------- | ---- |
| `_common-hardening.nix` | Security baseline (fail2ban, nftables, nginx hardening) | Both |
| `odoo.nix`              | Odoo + PostgreSQL + backup automation                   | noir |
| `btcpay.nix`            | BTCPay Server Docker stack                              | zinc |
| `pdf-intake.nix`        | Vendor PDF parser + Odoo integration                    | noir |
| `secrets.nix`           | sops-nix secret definitions                             | Both |

## Deployment

### Prerequisites

1. **Secrets Setup**: Create `secrets/research-relay.yaml` with required secrets (see `secrets.nix` for template)
2. **Age Key**: Generate encryption key at `infra/nixos/keys/relay.agekey`
3. **Cloudflare**: Configure DNS + origin certs + WAF rules
4. **ProtonMail**: Configure MX/SPF/DKIM for scientific-ops@research-relay.com

### Build & Deploy

```bash
# Check flake validity
nix flake check

# Build OCI images for GHCR
nix build .#packages.x86_64-linux.odooImage
nix build .#packages.x86_64-linux.pdfIntakeImage

# Deploy to noir (Odoo + PDF-intake)
sudo nixos-rebuild switch --flake .#noir

# Deploy to zinc (BTCPay)
sudo nixos-rebuild switch --flake .#zinc
```

### Enable Services

Services are disabled by default. Enable in machine configuration:

**noir** (`machines/noir/configuration.nix`):

```nix
services.researchRelay = {
  odoo.enable = true;
  pdfIntake.enable = true;
  ageGate.enable = true;  # Age verification (18+)
};
```

**zinc** (`machines/zinc/configuration.nix`):

```nix
services.researchRelay = {
  btcpay.enable = true;
};
```

## Security Features

### Common Hardening

- SSH key-only authentication (no passwords)
- fail2ban for brute-force protection
- nftables firewall (ports 22, 80, 443 only)
- Nginx security headers (HSTS, CSP, X-Frame-Options)
- Rate limiting (10 req/s general, 30 req/s API)
- Kernel hardening via sysctl

### Odoo Security

- **Age verification gate** - nginx + Lua enforced 18+ age check (see [AGE_GATE.md](AGE_GATE.md))
- **US-only checkout** - nginx + Cloudflare WAF enforcement
- **Session cookies** - 24-hour age verification (HttpOnly, Secure, SameSite)
- Proxy mode for Cloudflare X-Forwarded-\* headers
- Separate admin credentials

### BTCPay Security

- Isolated host (zinc) with dedicated wallet
- Encrypted backups with age encryption
- No shared secrets between hosts
- Bitcoin P2P port (8333) for full node connectivity

## Backup Strategy

### Odoo (noir)

- **Schedule**: Nightly at midnight
- **Retention**: 30 days
- **Location**: `/var/backups/research-relay/odoo-YYYY-MM-DD.sql.gz`
- **Method**: pg_dump → gzip

### BTCPay (zinc)

- **Schedule**: Nightly at midnight
- **Retention**: 60 days (financial records)
- **Location**: `/var/backups/research-relay/btcpay/`
- **Method**: tar + age encryption
- **Contents**: Wallet seeds, store config, PostgreSQL database

### Restore Testing

Monthly restore verification required for both services.

## Integration Points

### Odoo ↔ BTCPay

- Odoo creates invoice via BTCPay API
- BTCPay sends webhook to Odoo on payment
- Webhook secret validation for security

### Odoo ↔ PDF-Intake

- PDF-Intake calls Odoo XML-RPC API
- Service account authentication
- Manual review before price updates

## CI/CD

GitHub Actions workflow (`.github/workflows/ci.yml`):

1. `nix flake check` - Validate flake
2. Build OCI images for both services
3. Push to GHCR (`ghcr.io/scientific-oops/research-relay-*`)
4. Optional: Deploy via SSH to homelab

## DNS Configuration

### Cloudflare DNS Records

```
research-relay.com         A      <noir-ip>         (proxied)
www.research-relay.com     A      <noir-ip>         (proxied)
pay.research-relay.com     A      <zinc-ip>         (proxied)
```

### ProtonMail Records

- MX: `mail.protonmail.ch` (priority 10)
- SPF: `v=spf1 include:_spf.protonmail.ch ~all`
- DKIM: (from ProtonMail dashboard)
- DMARC: `v=DMARC1; p=quarantine; rua=mailto:scientific-ops@research-relay.com`

## Monitoring

**Current**: Systemd service status + journal logs

**Future** (optional via services-flake):

- Prometheus metrics collection
- Loki log aggregation
- Grafana dashboards

## Development

### Local Dev Services (services-flake)

```bash
# Start local Postgres + Redis for development
nix run .#devservices

# Stop services
nix run .#devservices -- stop
```

### Test Changes Locally

```bash
# Build NixOS config without deploying
nix build .#nixosConfigurations.noir.config.system.build.toplevel
nix build .#nixosConfigurations.zinc.config.system.build.toplevel

# Check for eval errors
nix flake show
```

## Troubleshooting

### Odoo Won't Start

```bash
# Check logs
journalctl -u odoo -f

# Verify PostgreSQL
sudo -u postgres psql -l | grep odoo

# Check config
cat /var/lib/odoo/odoo.conf
```

### BTCPay Docker Issues

```bash
# Check container status
docker ps -a

# View logs
docker logs btcpay-btcpayserver-1

# Restart stack
systemctl restart btcpay
```

### Backup Failures

```bash
# Check backup logs
journalctl -u odoo-backup -f
journalctl -u btcpay-backup -f

# Verify backup directory
ls -lah /var/backups/research-relay/
```

### Secret Access Issues

```bash
# Check sops key permissions
ls -la /nix/secret/initrd/ssh_host_ed25519_key

# Verify secret decryption
systemctl status sops-install-secrets
```

## Support

For issues specific to Research Relay services:

- **Repository**: `scientific-oops/research-relay`
- **Email**: scientific-ops@research-relay.com (ProtonMail)
- **Domain**: research-relay.com (Cloudflare managed)
