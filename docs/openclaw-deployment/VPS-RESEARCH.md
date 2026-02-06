# VPS Research: OpenClaw Deployment

## Requirements

OpenClaw with external API (Claude/Anthropic) has modest resource needs:

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| RAM | 2 GB | 4-8 GB |
| vCPU | 1-2 | 2-4 |
| Storage | 10 GB | 40-80 GB |
| Traffic | Low (~few GB/month) | 20 TB included |

Adding Ollama (llama3.2:3b for heartbeats only) adds ~2GB RAM usage and ~2GB storage for the model weights. No GPU needed for a 3B parameter model — CPU inference is fine for simple heartbeat responses.

**Total recommended: 4 vCPU, 8 GB RAM, 80 GB SSD** (covers OpenClaw + Ollama + NixOS store comfortably).

## Provider Comparison

### Hetzner Cloud (Recommended)

**Why Hetzner:**
- Ranked #1 Best Global VPS 2025 and 2026 by VPSBenchmarks
- Best NixOS support in the community (official NixOS wiki page, nixos-anywhere tested)
- Transparent hourly billing with monthly cap (no lock-in)
- 20 TB traffic included on all plans
- Data centers in Germany, Finland, USA, Singapore
- IPv4 + IPv6 included, DDoS protection included

**Relevant Plans:**

| Plan | vCPU | RAM | Storage | Price/mo | Notes |
|------|------|-----|---------|----------|-------|
| **CX22** | 2 shared | 4 GB | 40 GB NVMe | €3.79 | Minimum viable for API-only |
| **CX32** | 4 shared | 8 GB | 80 GB NVMe | €6.80 | **Best fit** — room for Ollama |
| **CAX11** | 2 ARM | 4 GB | 40 GB NVMe | €3.79 | ARM alternative (EU only) |
| **CAX21** | 4 ARM | 8 GB | 80 GB NVMe | €6.49 | Cheapest 8GB option |
| **CX42** | 8 shared | 16 GB | 160 GB NVMe | €16.40 | Overkill unless running local LLMs |

**Backup add-on:** +20% of instance cost (€1.36/mo for CX32)

#### NixOS Installation on Hetzner

Three proven methods:
1. **nixos-anywhere** (recommended) — Uses kexec to boot into NixOS installer, supports custom disko configurations. Best for declarative disk setup matching our impermanence pattern.
2. **nixos-infect** — Overwrites existing Ubuntu/Debian install with NixOS. Simpler but less control over disk layout.
3. **ISO mount** — Upload custom ISO via Hetzner rescue mode. Most control but most manual steps.

### Contabo

**Pros:** Cheapest raw specs per dollar
**Cons:** Weaker performance, slower provisioning, requires hostname workaround for NixOS

| Plan | vCPU | RAM | Storage | Price/mo |
|------|------|-----|---------|----------|
| Cloud VPS S | 4 | 8 GB | 50 GB NVMe | €4.50 |
| Cloud VPS M | 6 | 16 GB | 100 GB NVMe | €8.49 |

**NixOS caveats:** Contabo sets hostname to `vmi######.contaboserver.net` which violates RFC 1035. Must run `hostname something_clean` before nixos-infect. Community reports mixed reliability.

### OVHcloud

**Pros:** Good global network, low prices
**Cons:** Weak RAM performance in benchmarks, `/tmp` tmpfs issue with nixos-infect, slow support

| Plan | vCPU | RAM | Storage | Price/mo |
|------|------|-----|---------|----------|
| Starter | 1 | 2 GB | 20 GB | €3.50 |
| Essential | 2 | 4 GB | 40 GB | €6.00 |
| Comfort | 4 | 8 GB | 80 GB | €12.00 |

**NixOS caveats:** Must `umount /tmp` before running nixos-infect (OVH adds a small tmpfs that causes OOM). nixos-anywhere works but requires more manual setup.

### DigitalOcean

**Pros:** 1-Click OpenClaw deploy available, good docs
**Cons:** More expensive for equivalent specs, 1-Click image is Ubuntu-based (not NixOS)

| Plan | vCPU | RAM | Storage | Price/mo |
|------|------|-----|---------|----------|
| Basic | 1 | 2 GB | 50 GB | $12 |
| Basic | 2 | 4 GB | 80 GB | $24 |

Not competitive on price. The 1-Click deploy doesn't help since we want NixOS.

## Recommendation

### Primary: Hetzner CX32 — €6.80/month (~$7.50)

- 4 vCPU, 8 GB RAM, 80 GB NVMe SSD
- Plenty of headroom for OpenClaw + Ollama + NixOS store
- Best NixOS community support
- nixos-anywhere proven workflow
- Hourly billing (can test and destroy without full month charge)
- 20 TB traffic included
- With backups: €8.16/month (~$9.00)

### Budget Alternative: Hetzner CX22 — €3.79/month (~$4.20)

- 2 vCPU, 4 GB RAM, 40 GB NVMe SSD
- Sufficient for API-only OpenClaw without Ollama
- Can upgrade to CX32 later with one click (no data loss)
- Good starting point to validate the setup

### ARM Alternative: Hetzner CAX21 — €6.49/month (~$7.15)

- 4 ARM vCPU (Ampere Altra), 8 GB RAM, 80 GB NVMe
- Slightly cheaper than CX32 for same specs
- Better performance per euro for Docker workloads
- **Caveat:** EU data centers only; NixOS aarch64-linux builds required
- **Caveat:** OpenClaw Docker images must support ARM (verify before choosing)

## Provisioning Steps

1. Sign up at [hetzner.com/cloud](https://www.hetzner.com/cloud)
2. Create a project (e.g., "goodlab")
3. Add SSH public key to project
4. Create server: CX32, Falkenstein (DE) or Ashburn (US), Ubuntu 24.04 (temporary)
5. Note the public IPv4 address
6. Run `nixos-anywhere` from local machine to install NixOS with custom disko config
7. Verify SSH access to fresh NixOS install
8. Extract age key: `ssh root@<ip> "cat /etc/ssh/ssh_host_ed25519_key.pub" | ssh-to-age`
9. Add key to `.sops.yaml`, run `just sopsupdate`
10. Deploy: `just deploy claw <ip>`

## Sources

- [Hetzner Cloud Pricing](https://www.hetzner.com/cloud)
- [Hetzner CX Cost-Optimized Plans](https://www.bitdoze.com/hetzner-cloud-cost-optimized-plans/)
- [Install NixOS on Hetzner Cloud — NixOS Wiki](https://wiki.nixos.org/wiki/Install_NixOS_on_Hetzner_Cloud)
- [NixOS Friendly Hosters — NixOS Wiki](https://nixos.wiki/wiki/NixOS_friendly_hosters)
- [Contabo vs Hetzner Comparison](https://hostadvice.com/tools/web-hosting-comparison/contabo-vs-hetzner/)
- [OpenClaw Hardware Requirements](https://boostedhost.com/blog/en/openclaw-hardware-requirements/)
- [OpenClaw Docker Deployment](https://docs.openclaw.ai/install/docker)
- [nixos-anywhere](https://github.com/nix-community/nixos-anywhere)
