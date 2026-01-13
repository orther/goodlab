# Email Template: Domain Whitelist Request

Use this template to request domain whitelisting from your IT department.

## Short Version (< 200 words)

```
Subject: Domain Whitelist Request - Development Infrastructure (Nix Package Manager)

Hi [IT Team/Security Team],

I'm requesting whitelist access for domains required by Nix, a declarative package manager used for reproducible development environments.

Currently, Zscaler is blocking legitimate infrastructure domains, preventing me from applying system configurations and security updates. This impacts ~[X] hours per week in lost productivity.

**Domains Required:**
- cache.nixos.org - Binary package cache (reduces build time hours → seconds)
- channels.nixos.org - Update channels
- github.com, raw.githubusercontent.com, api.github.com - Source repositories
- proxy.golang.org, sum.golang.org - Go module infrastructure (required for tools like sops, age)

**Error Example:**
```

error: unable to download 'https://proxy.golang.org/...': HTTP error 403

```

**Business Justification:**
- Declarative infrastructure-as-code approach improves security and reproducibility
- Matches industry standard practices (used at GitHub, Shopify, Replit, etc.)
- Enables consistent development environment across team
- Required for automated security updates and compliance

These are all legitimate development infrastructure domains. Happy to provide additional details or meet to discuss.

Thank you,
[Your Name]
```

## Detailed Version (with background)

```
Subject: Domain Whitelist Request - Nix Development Infrastructure

Hi [IT Team/Security Team],

I'm using Nix, a declarative package manager that treats infrastructure as code. Think of it as version control for your entire development environment - every tool, dependency, and configuration is specified in code and reproducible.

**The Problem:**
Zscaler is blocking domains that Nix requires to download packages and apply configurations. This prevents me from:
- Applying system security updates
- Installing or updating development tools
- Maintaining consistent configuration across machines
- Following our infrastructure-as-code practices

**Impact:**
- ~[X] hours per week troubleshooting proxy issues
- Unable to apply security patches promptly
- Inconsistent development environment increases bug risk

**Domains Needed:**

*Core Infrastructure (Critical):*
- cache.nixos.org - Pre-built binary packages (like apt.ubuntu.com or yum repos)
- channels.nixos.org - Update channels and metadata
- nixos.org - Official documentation

*Source Code Repositories (Critical):*
- github.com - Package source code and configurations
- raw.githubusercontent.com - Raw file access
- api.github.com - Release and version information

*Go Language Infrastructure (Required for security tools):*
- proxy.golang.org - Go module proxy
- sum.golang.org - Go cryptographic checksum database
- go.googlesource.com - Official Go repositories

**Current Error:**
```

error: unable to download 'https://proxy.golang.org/golang.org/x/crypto/@v/v0.1.0.mod': HTTP error 403
error: build of '/nix/store/...-sops-install-secrets.drv' failed

```

**Why These Are Safe:**
- All are official infrastructure for open-source package management
- Used by thousands of developers at companies like GitHub, Shopify, Replit, Tweag
- Content is cryptographically verified (Nix uses SHA-256 hashes)
- No executable code runs directly from these domains - everything is verified first

**Business Value:**
- Infrastructure-as-code = better security through reproducibility
- Declarative configurations = easier compliance auditing
- Fewer "works on my machine" issues = higher productivity
- Industry standard approach for modern DevOps

I'm happy to meet with security team to discuss this in detail or provide additional information about how Nix's security model works.

Thank you for your consideration,
[Your Name]
```

## Follow-up Template (if initially denied)

```
Subject: Re: Domain Whitelist Request - Alternative Solutions?

Hi [IT Contact],

Thanks for reviewing my request. I understand security is paramount.

Could we discuss alternatives?

**Options:**
1. Whitelist only the critical subset:
   - cache.nixos.org (binary cache - most important)
   - github.com (already widely used)
   - proxy.golang.org (Go tooling infrastructure)

2. Time-limited trial (e.g., 30 days) to demonstrate value

3. VPN/network segment exception for development team

4. Meeting with security team to review Nix's security model
   - Can show how cryptographic verification works
   - Discuss why these domains are industry-standard

The current proxy blocks are preventing me from following infrastructure-as-code best practices and keeping tools updated. I'd like to find a solution that works within our security requirements.

Available for a call anytime this week.

Thanks,
[Your Name]
```

## Tips for Success

### DO:

- Keep initial email under 200 words
- Lead with business impact (time lost, security updates blocked)
- Use familiar analogies (like apt/yum repositories)
- Offer to meet and explain in detail
- Mention other companies using the same tools
- Emphasize security benefits of declarative config

### DON'T:

- Use excessive technical jargon
- Sound frustrated or demanding
- Assume they know what Nix is
- Send a novel - IT gets lots of tickets
- Forget to quantify impact (hours/week lost)

### Timing:

- Send during business hours (better response rate)
- Include your manager if escalation is needed
- Follow up after 3-5 business days if no response

### Evidence to Attach:

1. Screenshot of 403 error
2. List of blocked domains (from troubleshooting guide)
3. Link to this documentation in your repo (shows you're organized)
4. Optional: Link to Nix website or security model documentation

## Common IT Questions & Answers

**Q: Why can't you use Docker/Vagrant/Homebrew instead?**
A: Nix provides reproducibility those tools can't - the entire system state is versioned and declarative. But I'm happy to use those alongside Nix.

**Q: How do we know these domains are safe?**
A: They're official infrastructure for open-source development, verified by cryptographic hashes. Similar to whitelisting ubuntu.com or microsoft.com.

**Q: Can you work around this?**
A: Only by using my phone's hotspot, which violates our security policy and defeats the purpose of the corporate network.

**Q: What if these domains get compromised?**
A: Nix's content-addressing means compromised content would fail hash verification. Unlike traditional package managers, you'd get an error rather than installing malicious code.

**Q: Why so many domains?**
A: Similar to how Visual Studio needs access to Microsoft domains, Docker needs docker.io, etc. These are the standard infrastructure domains for the Nix ecosystem.

## Escalation Path

If your initial request is denied:

1. **Week 1**: Send initial request
2. **Week 2**: Send follow-up with alternatives
3. **Week 3**: Request meeting with security team
4. **Week 4**: Loop in your manager
5. **Week 5+**: Consider:
   - Demonstrating tool on personal machine
   - Formal exception request process
   - Alternative development approach (if all else fails)

## Success Metrics to Report Back

Once approved, track and report back to IT:

- Time saved per week
- Number of successful builds
- Security updates applied
- Team members able to use consistent environments

This helps justify the decision and makes future requests easier.
