# Research Relay - Quick Start Guide

## Initial Setup (One-Time)

### 1. Generate Secrets

```bash
# Generate age key for backup encryption
age-keygen -o backup.key
age-keygen -y backup.key  # Copy public key for secrets.yaml

# Generate API tokens
openssl rand -hex 32  # For PDF-intake API token
openssl rand -hex 32  # For BTCPay webhook secret
```

### 2. Configure Secrets

```bash
# Copy template
cp services/research-relay/secrets.yaml.example secrets/research-relay.yaml

# Edit with your values
nano secrets/research-relay.yaml

# Configure sops (if not already done)
# Add age key to .sops.yaml:
# creation_rules:
#   - path_regex: secrets/research-relay\.yaml$
#     age: >-
#       age1...your_public_key_here

# Encrypt secrets
sops -e -i secrets/research-relay.yaml
```

### 3. Obtain Cloudflare Origin Certificates

1. Login to Cloudflare Dashboard
2. Select `research-relay.com` domain
3. SSL/TLS → Origin Server → Create Certificate
4. Save certificate and private key
5. Add to `secrets/research-relay.yaml`:
   - `cloudflare-origin-cert`
   - `cloudflare-origin-key`

### 4. Configure Cloudflare DNS

```
research-relay.com         A      <noir-ip>     (proxied ☁️)
www.research-relay.com     A      <noir-ip>     (proxied ☁️)
pay.research-relay.com     A      <zinc-ip>     (proxied ☁️)
```

### 5. Configure Cloudflare WAF Rules

Create firewall rule for US-only checkout:

**Rule Name**: Block non-US checkout
**Expression**:
```
(http.request.uri.path contains "/shop/cart" or http.request.uri.path contains "/shop/checkout") and ip.geoip.country ne "US"
```
**Action**: Block

## Deployment

### Build & Deploy to noir (Odoo + PDF-intake)

```bash
# Build configuration
nix build .#nixosConfigurations.noir.config.system.build.toplevel

# Deploy
sudo nixos-rebuild switch --flake .#noir

# Verify services
systemctl status odoo
systemctl status pdf-intake-api
systemctl status pdf-intake-worker
systemctl status postgresql
```

### Build & Deploy to zinc (BTCPay Server)

```bash
# Build configuration
nix build .#nixosConfigurations.zinc.config.system.build.toplevel

# Deploy
sudo nixos-rebuild switch --flake .#zinc

# Verify services
systemctl status btcpay
docker ps
systemctl status nginx
```

## Post-Deployment Configuration

### Odoo Initial Setup

1. Access Odoo: `https://research-relay.com`
2. Create database: `odoo`
3. Set admin password (from secrets)
4. Install modules:
   - Website
   - eCommerce
   - Inventory
   - Purchase
5. Configure payment provider:
   - Go to Website → Configuration → Payment Providers
   - Add BTCPay Server provider
   - URL: `https://pay.research-relay.com`
   - API Key: (from BTCPay after setup)

### BTCPay Server Initial Setup

1. Access BTCPay: `https://pay.research-relay.com`
2. Create account (first user is admin)
3. Create store: "Research Relay"
4. Setup Bitcoin wallet:
   - Create new wallet OR
   - Import existing (recommended for production)
5. Generate API key:
   - Account → API Keys → Generate
   - Permissions: `btcpay.store.canmodifystorewithid:*`
   - Copy to Odoo payment provider config
6. Configure webhook:
   - Store → Settings → Webhooks
   - URL: `https://research-relay.com/payment/btcpay/webhook`
   - Secret: (from `secrets/research-relay.yaml`)
   - Events: Invoice settled, Invoice expired

### PDF-Intake Service Account

1. Login to Odoo as admin
2. Settings → Users & Companies → Users
3. Create New:
   - Name: "PDF Intake Service"
   - Login: `pdf_intake_service`
   - Password: (from `secrets/research-relay.yaml`)
   - Access Rights: Inventory/Administrator
4. Save

## Testing

### Test Odoo

```bash
# Check database
sudo -u postgres psql -l | grep odoo

# Check Odoo logs
journalctl -u odoo -f

# Test website
curl -I https://research-relay.com
```

### Test BTCPay

```bash
# Check containers
docker ps | grep btcpay

# Check logs
docker logs btcpay-btcpayserver-1

# Test API
curl https://pay.research-relay.com/api/v1/health
```

### Test PDF-Intake

```bash
# Check services
systemctl status pdf-intake-api
systemctl status pdf-intake-worker

# Check Redis
redis-cli -p 6380 -a $(cat /run/secrets/research-relay/pdf-intake/redis-password) ping

# Test API (requires auth token)
curl -H "Authorization: Bearer YOUR_TOKEN" \
  http://localhost:8071/health
```

## Backups

### Manual Backup

```bash
# Odoo backup
sudo systemctl start odoo-backup

# BTCPay backup
sudo systemctl start btcpay-backup

# Verify backups
ls -lah /var/backups/research-relay/
```

### Restore from Backup

**Odoo**:
```bash
# Stop service
sudo systemctl stop odoo

# Restore database
gunzip < /var/backups/research-relay/odoo-YYYY-MM-DD.sql.gz | \
  sudo -u postgres psql odoo

# Start service
sudo systemctl start odoo
```

**BTCPay**:
```bash
# Stop service
sudo systemctl stop btcpay

# Decrypt and extract backup
age -d -i /path/to/backup.key \
  /var/backups/research-relay/btcpay/btcpay-data-YYYY-MM-DD.tar.gz.age | \
  tar xzf - -C /var/lib/btcpay/btcpay

# Restore database
age -d -i /path/to/backup.key \
  /var/backups/research-relay/btcpay/btcpay-db-YYYY-MM-DD.sql.gz.age | \
  gunzip | docker exec -i btcpay-postgres-1 psql -U btcpay btcpay

# Start service
sudo systemctl start btcpay
```

## Monitoring

### Check Service Health

```bash
# All Research Relay services on noir
systemctl status odoo pdf-intake-api pdf-intake-worker postgresql redis-pdf-intake

# BTCPay on zinc
systemctl status btcpay
docker ps -a

# Nginx on both hosts
systemctl status nginx
```

### View Logs

```bash
# Odoo
journalctl -u odoo -f

# BTCPay
docker logs -f btcpay-btcpayserver-1

# PDF-Intake
journalctl -u pdf-intake-api -f
journalctl -u pdf-intake-worker -f

# Nginx access logs
tail -f /var/log/nginx/access.log
```

### Backup Status

```bash
# Check last backup times
ls -lt /var/backups/research-relay/ | head

# Check backup service status
systemctl status odoo-backup
systemctl status btcpay-backup

# Check timer schedules
systemctl list-timers | grep -E 'odoo|btcpay'
```

## Troubleshooting

### Odoo won't start

1. Check PostgreSQL: `systemctl status postgresql`
2. Check database: `sudo -u postgres psql -l | grep odoo`
3. Check config: `cat /var/lib/odoo/odoo.conf`
4. Check secrets: `systemctl status sops-install-secrets`
5. View logs: `journalctl -u odoo -n 100`

### BTCPay containers failing

1. Check Docker: `systemctl status docker`
2. Check compose file: `cat /var/lib/btcpay/docker-compose.yml`
3. View container logs: `docker logs btcpay-btcpayserver-1`
4. Restart stack: `systemctl restart btcpay`

### SSL/TLS errors

1. Check Cloudflare origin cert: `openssl x509 -in /path/to/cert -text -noout`
2. Check nginx config: `nginx -t`
3. Verify Cloudflare proxy is enabled (orange cloud)
4. Check firewall: `nft list ruleset | grep -E '80|443'`

### Payment webhook not working

1. Verify webhook secret matches in both Odoo and BTCPay
2. Check BTCPay webhook logs: Store → Webhooks → View Details
3. Test connectivity: `curl https://research-relay.com/payment/btcpay/webhook`
4. Check Odoo logs for webhook processing errors

## Security Checklist

- [ ] All secrets encrypted with sops
- [ ] Cloudflare WAF rule blocking non-US checkout
- [ ] fail2ban enabled and monitoring SSH
- [ ] Firewall rules limiting ports to 22, 80, 443
- [ ] Backups encrypted with age
- [ ] BTCPay wallet seed backed up offline
- [ ] SSH key-only authentication (no passwords)
- [ ] Nginx security headers enabled
- [ ] Rate limiting configured
- [ ] Monthly backup restore testing scheduled

## Maintenance

### Monthly Tasks

- [ ] Test backup restore procedures
- [ ] Review fail2ban logs for attack patterns
- [ ] Check disk usage: `df -h`
- [ ] Review Cloudflare WAF analytics
- [ ] Update BTCPay if new version available
- [ ] Rotate API tokens/secrets (quarterly)

### Update Process

```bash
# Update flake inputs
nix flake update

# Test locally
nix build .#nixosConfigurations.noir.config.system.build.toplevel
nix build .#nixosConfigurations.zinc.config.system.build.toplevel

# Deploy
sudo nixos-rebuild switch --flake .#noir
sudo nixos-rebuild switch --flake .#zinc

# Verify services
systemctl status odoo btcpay
```

## Support

- **Repository**: https://github.com/scientific-oops/research-relay
- **Email**: scientific-ops@research-relay.com
- **Documentation**: services/research-relay/README.md
