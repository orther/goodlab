# ADR-0001: Clawdbot Gateway Deployment Location

**Status**: Accepted

**Date**: 2026-01-26

**Deciders**: Brandon Orther

**Technical Story**: Setting up Clawdbot (self-hosted AI assistant) for personal use with messaging platform integrations (Telegram, Discord, etc.)

---

## Context

We need to deploy Clawdbot, a self-hosted AI assistant that provides:

- 24/7 availability through messaging platforms (Telegram, Discord, WhatsApp, Slack, Signal, iMessage)
- Persistent memory across conversations
- Tool execution and system integration
- Multi-device access

### Architecture Understanding

Clawdbot uses a **gateway/client architecture**:

- **Gateway**: Control plane that manages messaging platforms, sessions, agents, and state. Runs as a daemon with WebSocket interface on `ws://127.0.0.1:18789`
- **Clients**: macOS app, CLI, WebChat, mobile apps that connect to the gateway

**Key insight**: macOS-specific features (menu bar app, TCC permissions, iMessage, Canvas UI automation) are **client-side**, not gateway features. The gateway itself is platform-agnostic.

### Available Infrastructure

| Machine  | Platform      | CPU                 | RAM (estimated) | Current Role                   | Tailscale | Uptime   |
| -------- | ------------- | ------------------- | --------------- | ------------------------------ | --------- | -------- |
| **noir** | x86_64 NixOS  | Intel (kvm-intel)   | 32GB+           | Research Relay (being removed) | ✅        | 24/7     |
| **zinc** | x86_64 NixOS  | Intel               | 8-16GB          | BTCPay Server                  | ✅        | 24/7     |
| **pie**  | x86_64 NixOS  | Intel (Coffee Lake) | 16GB+           | Jellyfin + Transcoding         | ✅        | 24/7     |
| **stud** | aarch64 macOS | Apple Silicon       | 32GB+           | Workstation                    | ❓        | Variable |

_RAM estimates based on tmpfs root allocation: noir (16G), zinc (4G), pie (estimated from Mac Mini spec)_

### Resource Requirements

Clawdbot gateway needs minimal resources:

- **Minimum**: 1 vCPU, 1GB RAM, ~500MB disk (basic chat)
- **Recommended**: 1-2 vCPU, 2GB RAM (multiple channels)
- **Heavy usage**: 4GB RAM (browser automation, intensive workflows)

### Decision Drivers

1. **Availability**: Gateway must be always-on for persistent messaging connections
2. **Resource availability**: Need surplus capacity without impacting existing services
3. **Network stability**: Stable connection for WebSocket and messaging providers
4. **Declarative management**: Fit existing Nix infrastructure patterns
5. **Remote access**: Enable multi-device connectivity (macOS, mobile, CLI)
6. **Security**: Keep gateway on localhost with secure remote access via Tailscale

---

## Decision

**Deploy Clawdbot gateway on `noir` using declarative nix-clawdbot NixOS module.**

### Technical Implementation

1. **Gateway deployment**: noir (NixOS server)
   - Use `github:clawdbot/nix-clawdbot` flake input
   - Declarative NixOS module configuration
   - Systemd user service for automatic restart
   - SOPS-encrypted secrets (API keys, bot tokens)
   - Bind to localhost only (`127.0.0.1:18789`)

2. **Remote access**: Tailscale Serve mode
   - Enable Tailscale Serve for tailnet-only access
   - No public exposure (no Funnel)
   - Identity-based authentication via Tailscale headers
   - HTTPS automatic via Tailscale

3. **Client connections**:
   - **macOS (stud)**: Use app's "Remote over SSH" mode via Tailscale
   - **Mobile**: Connect via Tailscale MagicDNS
   - **CLI**: Remote mode with SSH tunnel or Tailscale

### Why noir Over Alternatives

**noir advantages**:

- ✅ Most available resources (32GB+ RAM, NVMe storage)
- ✅ Research Relay services being removed (freeing up capacity)
- ✅ Tailscale already configured
- ✅ Impermanence + SOPS patterns already established
- ✅ Stable network, always-on availability
- ✅ Room for future growth (browser automation, additional workflows)

**zinc disadvantages**:

- ❌ Less RAM (8-16GB vs 32GB+)
- ❌ Currently running BTCPay Server
- ❌ Less headroom for resource spikes

**pie disadvantages**:

- ❌ Heavy media transcoding workload
- ❌ Intel Quick Sync already utilized for Jellyfin
- ❌ Resource contention with transcoding jobs

**stud disadvantages**:

- ❌ Laptop sleeps/reboots break messaging connections
- ❌ Network changes (WiFi, location) cause disruptions
- ❌ OS updates interrupt service
- ❌ Not available when lid closed or away from desk

---

## Consequences

### Positive

- ✅ **24/7 availability**: Gateway always accessible regardless of laptop state
- ✅ **Multi-device access**: Connect from macOS, iOS, Android, any CLI
- ✅ **Resource headroom**: noir has capacity for browser automation and growth
- ✅ **Declarative infrastructure**: All configuration in git, reproducible
- ✅ **Secure by default**: Localhost binding + Tailscale = zero public exposure
- ✅ **Easy rollback**: NixOS generations enable instant recovery
- ✅ **Persistent memory**: Agent state survives laptop reboots/disconnections
- ✅ **Network stability**: Server connection more reliable than laptop WiFi

### Negative

- ⚠️ **Local file access limitation**: Gateway can't directly access stud's local files
  - _Mitigation_: Use device nodes (macOS app) for local file operations when needed
- ⚠️ **Additional dependency**: noir becomes critical infrastructure for AI assistant
  - _Mitigation_: Impermanence + SOPS ensure quick recovery; consider backup gateway later
- ⚠️ **Initial setup complexity**: Requires Tailscale + SSH tunnel configuration
  - _Mitigation_: macOS app's "Remote over SSH" mode handles tunnel automatically

### Neutral

- 📝 **State location**: Agent memory stored on server, not laptop
  - Benefit: Survives laptop replacement/reinstall
  - Consideration: Backup noir's `/nix/persist` for state preservation

---

## Remote Access Configuration

### Tailscale Serve Mode (Recommended)

**Gateway configuration** (`modules/nixos/clawdbot.nix`):

```nix
programs.clawdbot = {
  gateway = {
    bind = "loopback";  # 127.0.0.1 only
    tailscale = {
      mode = "serve";   # Tailnet-only (not public Funnel)
    };
    auth = {
      allowTailscale = true;  # Use Tailscale identity for auth
    };
  };
};
```

**Access via**:

- Tailscale MagicDNS: `https://noir.tail-scale.ts.net/`
- Identity-based auth (no password needed for tailnet members)

### SSH Tunnel (Alternative/Backup)

**Manual tunnel**:

```bash
ssh -N -L 18789:127.0.0.1:18789 orther@noir
```

**macOS app**: Use Settings → General → "Clawdbot runs" → "Remote over SSH"

- App manages tunnel automatically
- WebChat and health checks work seamlessly

**CLI configuration** (`~/.clawdbot/clawdbot.json`):

```json
{
  "gateway": {
    "mode": "remote",
    "remote": {
      "url": "ws://127.0.0.1:18789"
    }
  }
}
```

---

## Security Considerations

1. **No public exposure**: Gateway bound to `127.0.0.1` only
2. **Tailscale encryption**: All remote access over encrypted WireGuard mesh
3. **SOPS secret management**: API keys/tokens encrypted at rest
4. **Identity-based auth**: Tailscale Serve validates user identity via daemon
5. **No Funnel**: Explicitly avoiding public internet exposure
6. **Firewall**: No additional ports opened (Tailscale handles routing)

---

## Future Considerations

### Potential Enhancements

- **Backup gateway**: Consider running secondary gateway on zinc for redundancy
- **Browser automation**: noir has capacity for headless Chrome if needed
- **Device nodes**: Pair iOS/Android for camera/location-based automations
- **Monitoring**: Add health check alerts via existing netdata/monitoring stack

### Alternative Approaches Considered

1. **VPS deployment** (rejected)
   - Would require another server to manage
   - We already have suitable infrastructure
   - Cost vs existing hardware utilization

2. **Hybrid (local + remote)** (rejected)
   - Docs recommend single gateway for simplicity
   - Multiple gateways only for strict isolation needs
   - Adds unnecessary complexity

3. **Container deployment** (deferred)
   - nix-clawdbot NixOS module is more integrated
   - Can containerize later if needed for other platforms

---

## References

- [Clawdbot Gateway Architecture](https://docs.clawd.bot/gateway)
- [Clawdbot Remote Access](https://docs.clawd.bot/gateway/remote)
- [Clawdbot Tailscale Integration](https://docs.clawd.bot/gateway/tailscale)
- [GitHub: nix-clawdbot](https://github.com/clawdbot/nix-clawdbot)
- [Clawdbot macOS Platform](https://docs.clawd.bot/platforms/macos)
- [Resource Requirements Research](https://docs.clawd.bot/help/faq)

---

## Appendix: noir vs zinc Comparison Table

| Criterion    | noir                      | zinc           | Winner   |
| ------------ | ------------------------- | -------------- | -------- |
| RAM          | 32GB+                     | 8-16GB         | **noir** |
| Storage      | NVMe                      | SATA           | **noir** |
| Current Load | Research Relay (removing) | BTCPay Server  | **noir** |
| Headroom     | High                      | Medium         | **noir** |
| Tailscale    | ✅ Configured             | ✅ Configured  | Tie      |
| Impermanence | ✅                        | ✅             | Tie      |
| Network      | Stable, enp2s0            | Stable, enp1s0 | Tie      |

**Overall**: noir is the clear winner with 4x the RAM allocation, NVMe storage, and services being removed freeing up resources.
