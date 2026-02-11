# OpenClaw VPS Deployment Plan

## Overview

Deploy OpenClaw (formerly Clawdbot/Moltbot) to a dedicated VPS managed by this goodlab Nix flake. This plan covers deploying the clawdbot service to a purpose-built VPS, implementing token optimization strategies from the cost-reduction guide, and adding Ollama for local heartbeat routing.

**Current state:** Clawdbot has been removed from `noir`. The `nix-clawdbot` flake input is ready for the new `lildoofy` host.

**Target state:** OpenClaw runs on a dedicated Hetzner Cloud VPS (`lildoofy`) with token optimizations, Ollama heartbeat routing, model routing, and budget controls, with strict isolation controls:
- Dedicated SSH/admin keypair for `lildoofy` (no personal key reuse)
- Dedicated provider credentials for the bot (Telegram/Anthropic/Brave/Tailscale)
- Dedicated SOPS file and recipient rule for `lildoofy` secrets (no cross-host secret fanout)
- Tailscale-only ingress for SSH and gateway (no public `80/443` by default)

## Architecture

```
┌──────────────────────────────────────────────────────┐
│  Hetzner Cloud VPS "lildoofy" (CX33, Hillsboro)     │
│  NixOS + Impermanence                                │
│                                                      │
│  ┌──────────────────────────────────────────────┐   │
│  │ OpenClaw (Docker sandbox)                     │   │
│  │  ├── Gateway (port 18789)                     │   │
│  │  ├── Brain (Claude Haiku default)             │   │
│  │  ├── Telegram Provider                        │   │
│  │  └── Tools (Brave Search, Web Fetch)          │   │
│  └──────────────────────────────────────────────┘   │
│                                                      │
│  ┌──────────────────────────────────────────────┐   │
│  │ Ollama (llama3.2:3b)                          │   │
│  │  └── Heartbeat endpoint (localhost:11434)     │   │
│  └──────────────────────────────────────────────┘   │
│                                                      │
│  ┌──────────────────────────────────────────────┐   │
│  │ Tailscale (mesh VPN)                          │   │
│  │  └── SSH + gateway ingress only on tailnet    │   │
│  └──────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────┘
```

## Implementation Phases

### Phase 1: VPS Provisioning & NixOS Installation

**Goal:** Provision a Hetzner Cloud VPS and install NixOS via `nixos-anywhere`.

1. Create Hetzner Cloud account (if needed) and provision VPS
   - **Recommended:** CX33 (4 vCPU, 8GB RAM, 80GB NVMe) at ~$5.99/month
   - **Budget option:** CX23 (2 vCPU, 4GB RAM, 40GB NVMe) at ~$4.09/month
   - See [VPS-RESEARCH.md](./VPS-RESEARCH.md) for full comparison
2. Install NixOS using `nixos-anywhere` (kexec + disko approach)
3. Configure disk layout with impermanence (root on tmpfs, persistent `/nix`)
4. Set up dedicated `lildoofy` SSH/admin key and initial access

**Deliverables:**
- [ ] VPS provisioned on Hetzner Cloud
- [ ] NixOS installed via nixos-anywhere
- [ ] SSH access verified
- [ ] Age key generated and added to isolated `lildoofy` SOPS rule

### Phase 2: Flake Integration

**Goal:** Add the new `lildoofy` machine to the goodlab flake.

1. Create `hosts/lildoofy/default.nix` and `hosts/lildoofy/hardware-configuration.nix`
2. Add `lildoofy` to `flake.nix` nixosConfigurations
3. Add `lildoofy` age key to `.sops.yaml` with a dedicated `secrets/lildoofy-secrets.yaml` creation rule (before catch-all rule)
4. Add nixosEval smoke test for `lildoofy` to flake checks
5. Import base modules: `base`, `auto-update` (skip `remote-unlock`)
6. Configure host-local Tailscale settings with no route advertisement

**Deliverables:**
- [ ] `hosts/lildoofy/` directory with machine config
- [ ] `flake.nix` updated with `lildoofy` nixosConfiguration
- [ ] `.sops.yaml` updated with scoped `lildoofy` recipient rule
- [ ] `secrets/lildoofy-secrets.yaml` created for bot-only secrets
- [ ] `nix flake check` passes with `lildoofy` eval test
- [ ] `just deploy lildoofy <ip>` works

### Phase 3: OpenClaw Service Migration

**Goal:** Deploy the clawdbot/OpenClaw service on `lildoofy`.

1. Create `services/openclaw.nix` service module (using NIXOS-CONFIG.md template)
2. Configure `lildoofy` secrets using dedicated bot credentials (do not reuse personal credentials)
3. Set up Telegram, Anthropic, Brave Search integrations with dedicated keys/accounts
4. Configure SSH and gateway with Tailscale-only firewall rules
5. Verify service starts and Telegram bot responds

Note: Clawdbot was already removed from `noir` in a prior commit.

**Deliverables:**
- [ ] `services/openclaw.nix` — reusable service module
- [ ] SOPS secrets configured for `lildoofy`
- [ ] Telegram bot responding from new VPS
- [ ] Gateway accessible over Tailscale
- [x] ~~`noir` clawdbot disabled~~ (done)

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
| `hosts/lildoofy/default.nix` | Machine configuration |
| `hosts/lildoofy/hardware-configuration.nix` | Hardware/disk config (from nixos-anywhere) |
| `services/openclaw.nix` | Reusable OpenClaw service module |
| `services/ollama.nix` | Ollama local LLM service module |
| `clawdbot-documents/USER.md` | User context (new, for optimization) |
| `clawdbot-documents/IDENTITY.md` | Agent identity (new, for optimization) |

### Modified Files

| File | Change |
|------|--------|
| `flake.nix` | Add `lildoofy` nixosConfiguration + eval check |
| `.sops.yaml` | Add `lildoofy` age key + scoped creation rule for `lildoofy` secrets |
| `secrets/lildoofy-secrets.yaml` | New isolated secrets file for `lildoofy` credentials |
| `justfile` | No changes needed (deploy already supports any NixOS host) |
| ~~`hosts/noir/default.nix`~~ | ~~Disable clawdbot service~~ (done) |
| ~~`clawdbot-documents/AGENTS.md`~~ | ~~Update for VPS context~~ (done — references lildoofy) |
| `clawdbot-documents/SOUL.md` | Add budget/rate-limit rules |

## What Can't Be Done Automatically

These steps require manual intervention:

1. **Hetzner account setup** — Requires payment method, account creation at [hetzner.com/cloud](https://www.hetzner.com/cloud)
2. **VPS provisioning** — Must be done via Hetzner Cloud Console or `hcloud` CLI
3. **Initial SSH key upload** — First SSH key must be added via Hetzner Console
4. **nixos-anywhere execution** — Must be run from a machine with SSH access to the new VPS
5. **Age key extraction** — Run `ssh-to-age` against the VPS's host key after NixOS install
6. **SOPS re-encryption** — Run `just sopsupdate` after adding the new age key
7. **Telegram bot token** — Must be a dedicated bot token from @BotFather
8. **Anthropic credential** — Must come from a dedicated non-personal workspace/account
9. **Brave Search API key** — Must be a dedicated key for this bot/service
10. **Ollama model pull** — First run requires downloading llama3.2:3b (~2GB)
11. **Tailscale auth** — New device must be approved in Tailscale admin console
12. **Credential rotation** — Rotate/remove old bot secrets from `secrets/secrets.yaml` (clawdbot keys are still in the shared file)

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
