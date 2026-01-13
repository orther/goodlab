# Corporate Proxy (Zscaler) Troubleshooting Guide

This guide helps you systematically identify and document blocked domains when applying Nix configurations in corporate environments with MITM proxies like Zscaler.

## Quick Start: Collecting Blocked URLs

When you encounter build failures or proxy blocks, follow these steps to collect evidence for an IT whitelist request.

### 1. Capture Build Output

Run your Nix command with verbose logging to capture all network-related errors:

```bash
# For darwin-rebuild (macOS)
darwin-rebuild switch --flake .#nblap --show-trace 2>&1 | tee ~/nix-build-errors.log

# For nix build
nix build --verbose --show-trace 2>&1 | tee ~/nix-build-errors.log

# For nix flake check
nix flake check --verbose --show-trace 2>&1 | tee ~/nix-build-errors.log
```

### 2. Identify Blocked Domains

Look for these common error patterns in the output:

#### HTTP 403 Forbidden

```
error: unable to download 'https://proxy.golang.org/...': HTTP error 403
```

#### Connection Refused / Timeout

```
fatal: unable to access 'https://github.com/...': Failed to connect
error: unable to download 'https://cache.nixos.org/...': Couldn't connect to server
```

#### SSL/TLS Certificate Errors

```
error: unable to download '...': SSL certificate problem: unable to get local issuer certificate
```

#### DNS Resolution Failures

```
error: unable to download '...': Could not resolve host
```

### 3. Extract Blocked Domains

Use these commands to extract domains from your error log:

```bash
# Extract all URLs from errors
grep -oP 'https?://[^/]+' ~/nix-build-errors.log | sort -u > ~/blocked-domains.txt

# Common Nix infrastructure domains (check if accessible)
cat << 'EOF' > ~/nix-domains-to-check.txt
cache.nixos.org
channels.nixos.org
nixos.org
github.com
raw.githubusercontent.com
api.github.com
proxy.golang.org
sum.golang.org
go.googlesource.com
golang.org
EOF

# Test each domain
while read domain; do
  echo -n "Testing $domain: "
  curl -I "https://$domain" -m 5 2>&1 | grep -q "200\|301\|302" && echo "OK" || echo "BLOCKED"
done < ~/nix-domains-to-check.txt
```

### 4. Organize for IT Ticket

Create a summary document:

```bash
cat > ~/nix-whitelist-request.txt << 'EOF'
## Blocked Domains Identified

### Critical Infrastructure (Required)
- cache.nixos.org - Binary cache for Nix packages (reduces build time from hours to seconds)
- channels.nixos.org - Nix channel updates
- nixos.org - Official documentation and metadata

### Source Code Repositories (Required)
- github.com - Primary source for Nix packages and configurations
- raw.githubusercontent.com - Raw file access for GitHub repositories
- api.github.com - GitHub API for release information

### Go Language Infrastructure (Required for Go-based tools)
- proxy.golang.org - Go module proxy
- sum.golang.org - Go checksum database
- go.googlesource.com - Official Go source repositories

### Build Dependencies (May be required)
- (Add any additional domains from your blocked-domains.txt)

## Specific Errors Encountered
(Paste relevant error messages from nix-build-errors.log)

## Business Impact
- Unable to apply declarative system configuration
- Cannot update development tools and dependencies
- Blocked from security updates for system packages
- ~X hours per week lost troubleshooting proxy issues
EOF
```

## Common Blocked Domains by Category

### Core Nix Infrastructure

- `cache.nixos.org` - Binary cache (most important)
- `channels.nixos.org` - Channel definitions
- `nixos.org` - Main website and resources

### GitHub (Version Control & Packages)

- `github.com` - Repository hosting
- `raw.githubusercontent.com` - Raw file content
- `api.github.com` - API endpoints
- `codeload.github.com` - Archive downloads

### Language-Specific Package Registries

#### Go

- `proxy.golang.org` - Module proxy
- `sum.golang.org` - Checksum database
- `go.googlesource.com` - Official repositories

#### Rust

- `crates.io` - Crate registry
- `static.crates.io` - Static files

#### Python

- `pypi.org` - Package index
- `files.pythonhosted.org` - Package files

#### Node.js

- `registry.npmjs.org` - NPM registry
- `nodejs.org` - Node.js downloads

### Build Tools & Mirrors

- `dl.google.com` - Google downloads
- `downloads.sourceforge.net` - SourceForge
- `ftpmirror.gnu.org` - GNU mirror

## Understanding Fixed-Output Derivations

When you see errors mentioning "fixed-output derivation", this is Nix's security mechanism:

1. Nix builds are normally isolated from the network (sandbox)
2. Fixed-output derivations are an exception - they can access the network
3. They require a pre-known hash to verify the downloaded content
4. This is how Nix downloads source code, packages, and dependencies

**Important**: Corporate proxies can't block fixed-output derivations selectively. Either the domain works or it doesn't. There's no way to "proxy-exempt" individual builds.

## Workarounds (Temporary)

While waiting for IT approval, these may help:

### 1. Use a Personal Hotspot

Bypass corporate network entirely (not always allowed by policy).

### 2. Pre-fetch Dependencies

On a non-corporate network, pre-fetch and commit to a local cache:

```bash
# This won't work with proxy blocks, but good for future reference
nix copy --to file:///path/to/cache $(nix-store -qR $(nix-build))
```

### 3. Use Nix Binary Cache Substituters

Add additional binary cache sources in `~/.config/nix/nix.conf`:

```
substituters = https://cache.nixos.org https://nix-community.cachix.org
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=
```

## Prevention: Document Your Configuration

Keep a list of ALL domains your configuration needs in your repository:

```nix
# docs/required-domains.nix
{
  # Documentation only - list of domains required for this configuration
  requiredDomains = [
    "cache.nixos.org"
    "github.com"
    "proxy.golang.org"
    # Add others as discovered
  ];
}
```

Update this whenever you add dependencies that require new domains.

## See Also

- [Email template for IT](./it-whitelist-email-template.md)
- [Zscaler module documentation](../modules/macos/zscaler.nix)
- [Corporate network troubleshooting](../CLAUDE.md#corporate-environment-support)
