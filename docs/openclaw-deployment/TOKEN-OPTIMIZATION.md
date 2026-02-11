# Token Optimization Implementation Plan

## Background

The OpenClaw token optimization guide targets reducing monthly API costs from $1,500+ to $30-50 through four strategies. This document details how to implement each within our NixOS/flake-managed deployment.

## Isolation Prerequisite

Before applying token optimizations, ensure the bot runtime is isolated:

- Run on dedicated host `lildoofy`
- Use dedicated provider credentials (no personal login/session tokens)
- Use dedicated `lildoofy` SOPS secrets file/rule
- Restrict ingress to Tailscale

## Strategy 1: Session Initialization Optimization

### Problem

OpenClaw's default behavior loads all workspace files at session start, including large history files (~50KB). This costs ~$0.40 per session in input tokens.

### Solution

Configure OpenClaw to load only essential files at session start:

- `SOUL.md` — Core principles and values
- `USER.md` — User context and goals (new file)
- `IDENTITY.md` — Agent identity (new file)
- `memory/YYYY-MM-DD.md` — Today's memory file only

### Implementation

#### 1. Create new workspace files

**`clawdbot-documents/USER.md`** (new):

```markdown
# User Context

## Brandon Orther

- Software engineer working with Nix/NixOS, Go, TypeScript, Rust
- Manages homelab infrastructure as code (goodlab flake repository)
- Primary interests: systems programming, infrastructure automation, AI tooling
- Communication style: direct, technical, no fluff

## Goals

- Reliable personal AI assistant accessible via Telegram
- Cost-effective API usage ($30-50/month target)
- Privacy-preserving — no data sharing, local-first where possible
```

**`clawdbot-documents/IDENTITY.md`** (new):

```markdown
# Identity

You are **Lil Doofy**, Brandon's personal AI assistant.

## Platform

- Running on NixOS VPS (lildoofy) managed by goodlab flake
- Accessible via Telegram
- Using Anthropic Claude API with model routing

## Operating Rules

- Default to Claude Haiku for routine tasks
- Escalate to Claude Sonnet only for complex reasoning
- Heartbeat checks route to local Ollama (free)
- Budget cap: $5/day, $200/month (warn at 75%)
```

#### 2. Configure session loading in `openclaw.json`

This goes into the `configOverrides` section of the NixOS service:

```nix
configOverrides = {
  session = {
    # Load only essential files at startup
    initialFiles = [
      "SOUL.md"
      "USER.md"
      "IDENTITY.md"
    ];
    # Load today's memory file dynamically
    dailyMemory = true;
    # Don't auto-load history files
    autoLoadHistory = false;
  };
};
```

#### 3. Verification

After deployment, verify context size:

- Send `session_status` command via Telegram
- Target: 2-8KB initial context (down from ~50KB)
- Expected per-session cost: ~$0.05 (down from ~$0.40)

**Estimated savings:** ~$0.35/session = ~$10.50/month at 30 sessions/day

---

## Strategy 2: Model Routing

### Problem

Using Claude Sonnet for all tasks costs $50-70/month. Most interactions (quick lookups, status checks, simple Q&A) don't need Sonnet's reasoning capability.

### Solution

Default to Claude Haiku for routine work. Reserve Sonnet for complex multi-step reasoning.

### Implementation

#### 1. Configure model aliases in `openclaw.json`

```nix
configOverrides = {
  models = {
    default = "haiku";  # Use Haiku for most tasks
    aliases = {
      haiku = "claude-3-5-haiku-latest";
      sonnet = "claude-sonnet-4-20250514";
    };
  };
};
```

#### 2. Add model selection rules to SOUL.md

Append to `clawdbot-documents/SOUL.md`:

```markdown
## Model Selection

Use the cheapest model that can handle the task:

- **Haiku** (default): Quick answers, lookups, status checks, simple code, translations
- **Sonnet** (escalate): Multi-step reasoning, complex code generation, analysis, debugging

Never use Sonnet for:

- Greetings or small talk
- Simple factual lookups
- Weather/time/status queries
- One-line code snippets
```

#### 3. Verification

- Check active model via `session_status` command
- Haiku should be active for routine interactions
- Sonnet should only appear during complex tasks

**Estimated savings:** $40-60/month (model costs drop from $50-70 to $5-10)

---

## Strategy 3: Heartbeat Routing to Ollama

### Problem

OpenClaw sends periodic health-check heartbeats to the configured LLM API. These are simple "are you there?" pings that cost real API tokens.

### Solution

Route heartbeat checks to a local Ollama instance running a small, free model (llama3.2:3b). Zero API cost for health checks.

### Implementation

#### 1. Create `services/ollama.nix`

```nix
{config, pkgs, lib, ...}: {
  # Ollama for local LLM inference (heartbeats, simple tasks)
  services.ollama = {
    enable = true;
    # Bind only to localhost — not exposed externally
    host = "127.0.0.1";
    port = 11434;
    # Pull the lightweight model on first start
    loadModels = ["llama3.2:3b"];
  };

  # Persist Ollama models across reboots (impermanence)
  environment.persistence."/nix/persist" = {
    directories = ["/var/lib/ollama"];
  };
};
```

#### 2. Configure OpenClaw heartbeat routing

```nix
configOverrides = {
  heartbeat = {
    provider = "ollama";
    endpoint = "http://127.0.0.1:11434";
    model = "llama3.2:3b";
    interval = 60;  # seconds
  };
};
```

#### 3. Verification

- Check Ollama is running: `curl http://localhost:11434/api/tags`
- Verify heartbeat uses Ollama (not Anthropic) in OpenClaw logs
- Monitor Anthropic API usage — heartbeat calls should disappear

**Estimated savings:** $2-5/month (small but fully eliminates wasteful API calls)

### Resource Impact

- **RAM:** ~2GB additional for llama3.2:3b loaded in memory
- **Storage:** ~2GB for model weights in `/var/lib/ollama`
- **CPU:** Minimal — heartbeat inference is trivial for a 3B model
- **Why CX33 is recommended:** 8GB RAM comfortably fits OpenClaw (~2GB) + Ollama (~2GB) + NixOS overhead (~1-2GB) with headroom

---

## Strategy 4: Rate Limits & Budget Controls

### Problem

Without rate limiting, the agent can make rapid-fire API calls and web searches, running up costs unpredictably. No hard budget cap means a runaway conversation could blow the monthly budget.

### Solution

Add system prompt rules for rate limiting and configure budget caps in OpenClaw's configuration.

### Implementation

#### 1. Add rate limit rules to SOUL.md

Append to `clawdbot-documents/SOUL.md`:

```markdown
## Rate Limits

Follow these pacing rules strictly:

- **5 seconds minimum** between API calls
- **10 seconds minimum** between web searches
- **Max 5 searches** per conversation batch
- **Max 20 tool calls** per conversation turn
- If approaching daily budget (75% of $5), switch to Haiku-only mode
- If at daily budget limit, respond with "Daily budget reached — I'll be back tomorrow"
```

#### 2. Configure budget caps in `openclaw.json`

```nix
configOverrides = {
  budget = {
    daily = 5;     # $5/day hard cap
    monthly = 200;  # $200/month hard cap
    warnAt = 0.75;  # Warn at 75% usage
  };
};
```

#### 3. Monitoring

- Check budget status via `session_status` command
- Set up a simple cron job to log daily API spend
- Optionally forward budget warnings to Telegram

**Estimated savings:** Prevents runaway costs; caps total exposure at $200/month

---

## Combined Cost Projection

| Category                   | Before       | After          | Savings          |
| -------------------------- | ------------ | -------------- | ---------------- |
| Session initialization     | $12/month    | $1.50/month    | $10.50           |
| Model costs (Sonnet→Haiku) | $50-70/month | $5-10/month    | $40-60           |
| Heartbeat API calls        | $2-5/month   | $0 (local)     | $2-5             |
| Budget cap                 | Unbounded    | $200/month max | Risk elimination |
| **Total API costs**        | **$1,500+**  | **$30-50**     | **$1,450+**      |

Add VPS hosting: ~$7.20/month (Hetzner CX33 + backups)

**Total monthly cost: ~$39-59/month** (down from $1,500+)

---

## Implementation Order

1. Deploy VPS with Ollama (Phase 1-2 of main plan)
2. Configure session initialization optimization (lowest risk, immediate savings)
3. Enable model routing (biggest cost reduction)
4. Set up heartbeat routing to Ollama (requires Ollama to be running)
5. Add budget controls (safety net)
6. Verify all optimizations via `session_status`
7. Monitor for 1 week, then rotate old bot credentials from `secrets/secrets.yaml`

## What Can't Be Automated

- **Anthropic API usage dashboard** — Must manually verify token usage at [console.anthropic.com](https://console.anthropic.com) during initial rollout
- **Model routing accuracy** — May need manual tuning of which tasks get Haiku vs Sonnet
- **Budget threshold tuning** — $5/day and $200/month are starting points; adjust based on actual usage patterns
- **Ollama model updates** — While NixOS can manage the service, model updates (e.g., switching from llama3.2:3b to a newer model) require manual `ollama pull`
- **Prompt caching** — Claude's prompt caching (90% discount on reused static content) can further reduce costs but requires Sonnet 3.5+ and careful prompt structure; evaluate after initial optimization
