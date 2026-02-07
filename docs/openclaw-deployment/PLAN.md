# OpenClaw VPS Deployment Plan

## Overview

Deploy OpenClaw (formerly Clawdbot/Moltbot) to a dedicated VPS managed by this goodlab Nix flake. This plan covers migrating the existing `noir`-hosted clawdbot service to a purpose-built VPS, implementing the token optimization strategies from the cost-reduction guide, and adding Ollama for local heartbeat routing.

**Current state:** OpenClaw runs on `noir` (homelab x86_64 server) as `services.clawdbot` via `nix-clawdbot` flake input with Telegram, Anthropic, and Brave Search integrations.

**Target state:** OpenClaw runs on a dedicated Hetzner Cloud VPS (`claw`) with token optimizations, Ollama heartbeat routing, model routing, and budget controls — all managed declaratively through this flake.

## Architecture

```
┌─────────────────────────────────────────────────┐
│  Hetzner Cloud VPS "claw" (CX32 / CAX21)        │
│  NixOS + Impermanence                           │
│                                                  │
│  ┌──────────────────────────────────────────┐   │
│  │ OpenClaw (Docker sandbox)                 │   │
│  │  ├── Gateway (port 18789)                 │   │
│  │  ├── Brain (Claude Haiku default)         │   │
│  │  ├── Telegram Provider                    │   │
│  │  └── Tools (Brave Search, Web Fetch)      │   │
│  └──────────────────────────────────────────┘   │
│                                                  │
│  ┌──────────────────────────────────────────┐   │
│  │ Ollama (llama3.2:3b)                      │   │
│  │  └── Heartbeat endpoint (localhost:11434) │   │
│  └──────────────────────────────────────────┘   │
│                                                  │
│  ┌──────────────────────────────────────────┐   │
│  │ Nginx reverse proxy + ACME               │   │
│  │  └── Optional: web dashboard access       │   │
│  └──────────────────────────────────────────┘   │
│                                                  │
│  ┌──────────────────────────────────────────┐   │
│  │ Tailscale (mesh VPN)                      │   │
│  │  └── Secure access from homelab network   │   │
│  └──────────────────────────────────────────┘   │
└─────────────────────────────────────────────────┘
```

## Implementation Phases

### Phase 1: VPS Provisioning & NixOS Installation

**Goal:** Provision a Hetzner Cloud VPS and install NixOS via `nixos-anywhere`.

1. Create Hetzner Cloud account (if needed) and provision VPS
   - **Recommended:** CX32 (4 vCPU, 8GB RAM, 80GB NVMe) at €6.80/month
   - **Budget option:** CX22 (2 vCPU, 4GB RAM, 40GB NVMe) at €3.79/month
   - See [VPS-RESEARCH.md](./VPS-RESEARCH.md) for full comparison
2. Install NixOS using `nixos-anywhere` (kexec + disko approach)
3. Configure disk layout with impermanence (root on tmpfs, persistent `/nix`)
4. Set up SSH keys and initial access

**Deliverables:**
- [ ] VPS provisioned on Hetzner Cloud
- [ ] NixOS installed via nixos-anywhere
- [ ] SSH access verified
- [ ] Age key generated and added to `.sops.yaml`

### Phase 2: Flake Integration

**Goal:** Add the new `claw` machine to the goodlab flake.

1. Create `hosts/claw/default.nix` and `hosts/claw/hardware-configuration.nix`
2. Add `claw` to `flake.nix` nixosConfigurations
3. Add `claw` age key to `.sops.yaml` creation rules
4. Add nixosEval smoke test for `claw` to flake checks
5. Import base modules: `base`, `remote-unlock`, `auto-update`
6. Import services: `tailscale`, `_acme`, `_nginx`

**Deliverables:**
- [ ] `hosts/claw/` directory with machine config
- [ ] `flake.nix` updated with `claw` nixosConfiguration
- [ ] `.sops.yaml` updated with `claw` age key
- [ ] `nix flake check` passes with `claw` eval test
- [ ] `just deploy claw <ip>` works

### Phase 3: OpenClaw Service Migration

**Goal:** Move the clawdbot/OpenClaw service from `noir` to `claw`.

1. Create `services/openclaw.nix` service module (refactored from noir's inline config)
2. Configure SOPS secrets for `claw` (copy existing clawdbot secrets)
3. Set up Telegram, Anthropic, Brave Search integrations
4. Configure gateway with Tailscale-only firewall rules
5. Verify service starts and Telegram bot responds
6. Disable clawdbot service on `noir` once `claw` is confirmed working

**Deliverables:**
- [ ] `services/openclaw.nix` — reusable service module
- [ ] SOPS secrets configured for `claw`
- [ ] Telegram bot responding from new VPS
- [ ] Gateway accessible over Tailscale
- [ ] `noir` clawdbot disabled

### Phase 4: Token Optimization

**Goal:** Implement the four token optimization strategies from the cost guide.

See [TOKEN-OPTIMIZATION.md](./TOKEN-OPTIMIZATION.md) for detailed implementation.

1. **Session initialization** — Configure minimal file loading (SOUL.md, USER.md, IDENTITY.md, daily memory)
2. **Model routing** — Default to Claude Haiku, reserve Sonnet for complex tasks
3. **Heartbeat to Ollama** — Run Ollama with llama3.2:3b for free health checks
4. **Rate limits & budget controls** — System prompt rules + budget caps

**Deliverables:**
- [ ] `services/ollama.nix` — Ollama service module for local LLM
- [ ] Updated `clawdbot-documents/` with optimized workspace files
- [ ] `openclaw.json` configuration with model routing
- [ ] Budget control rules in system prompt
- [ ] Monthly API cost reduced to $30-50 target

### Phase 5: Monitoring & Hardening

**Goal:** Production-ready deployment with monitoring and security.

1. Enable `auto-update` module for daily flake rebuilds
2. Set up Kopia backups for persistent state
3. Configure fail2ban and nftables (reuse `_common-hardening.nix` patterns)
4. Add Netdata or similar lightweight monitoring
5. Document recovery procedures

**Deliverables:**
- [ ] Auto-update configured and tested
- [ ] Backup schedule for `/var/lib/clawdbot` and `/var/lib/ollama`
- [ ] Firewall hardening applied
- [ ] Monitoring dashboard accessible
- [ ] Runbook documented

## Files to Create/Modify

### New Files

| File | Purpose |
|------|---------|
| `hosts/claw/default.nix` | Machine configuration |
| `hosts/claw/hardware-configuration.nix` | Hardware/disk config (from nixos-anywhere) |
| `services/openclaw.nix` | Reusable OpenClaw service module |
| `services/ollama.nix` | Ollama local LLM service module |
| `clawdbot-documents/USER.md` | User context (new, for optimization) |
| `clawdbot-documents/IDENTITY.md` | Agent identity (new, for optimization) |

### Modified Files

| File | Change |
|------|--------|
| `flake.nix` | Add `claw` nixosConfiguration + eval check |
| `.sops.yaml` | Add `claw` age key |
| `secrets/secrets.yaml` | Re-encrypt with `claw` key |
| `justfile` | No changes needed (deploy already supports any NixOS host) |
| `hosts/noir/default.nix` | Disable clawdbot service (Phase 3 completion) |
| `clawdbot-documents/AGENTS.md` | Update for VPS context + model routing |
| `clawdbot-documents/SOUL.md` | Add budget/rate-limit rules |

## What Can't Be Done Automatically

These steps require manual intervention:

1. **Hetzner account setup** — Requires payment method, account creation at [hetzner.com/cloud](https://www.hetzner.com/cloud)
2. **VPS provisioning** — Must be done via Hetzner Cloud Console or `hcloud` CLI
3. **Initial SSH key upload** — First SSH key must be added via Hetzner Console
4. **nixos-anywhere execution** — Must be run from a machine with SSH access to the new VPS
5. **Age key extraction** — Run `ssh-to-age` against the VPS's host key after NixOS install
6. **SOPS re-encryption** — Run `just sopsupdate` after adding the new age key
7. **Telegram bot token** — If creating a new bot, must interact with @BotFather on Telegram
8. **Anthropic API key** — Must be created via Anthropic Console
9. **Brave Search API key** — Must be created via Brave Search API dashboard
10. **Ollama model pull** — First run requires downloading llama3.2:3b (~2GB)
11. **DNS records** — If using a custom domain, A/AAAA records must be configured
12. **Tailscale auth** — New device must be approved in Tailscale admin console

## Cost Estimate

| Item | Monthly Cost |
|------|-------------|
| Hetzner CX33 VPS (Hillsboro, OR) | $5.99 |
| Hetzner backups (+20%) | ~$1.20 |
| API costs (optimized) | $30-50 |
| **Total** | **~$37-57/month** |

vs. current estimated cost of $1,500+/month without optimization.

**Location:** Hillsboro, OR — ~20-30ms latency from San Diego, CA.

## Timeline

This plan is broken into 5 phases that can be executed incrementally. Phase 1-2 (infrastructure) should be completed before Phase 3-4 (service migration and optimization). Phase 5 (hardening) can run in parallel with Phase 4.

## Related Documents

- [HETZNER-SETUP-GUIDE.md](./HETZNER-SETUP-GUIDE.md) — Step-by-step manual guide for Hetzner account and VPS setup
- [CLAUDE-CODE-PROMPT.md](./CLAUDE-CODE-PROMPT.md) — Orchestration prompt to paste into Claude Code for NixOS deployment
- [VPS-RESEARCH.md](./VPS-RESEARCH.md) — VPS provider comparison and recommendation
- [TOKEN-OPTIMIZATION.md](./TOKEN-OPTIMIZATION.md) — Detailed token optimization implementation
- [NIXOS-CONFIG.md](./NIXOS-CONFIG.md) — NixOS configuration patterns for the new VPS
