# Modern Flake Migration Implementation Plan

## Stage 1: Introduce flake-parts skeleton
**Goal**: Convert `flake.nix` to use `flake-parts.lib.mkFlake` with a single `systems` definition and move `formatter` into `perSystem` while preserving existing `darwinConfigurations` and `nixosConfigurations`.
**Success Criteria**: `nix flake show` lists the same host configurations; `formatter` is available for all systems; evaluation succeeds without changing machine semantics.
**Tests**:
- `nix eval .#darwinConfigurations` and `nix eval .#nixosConfigurations` succeed
- `nix flake show` includes `formatter` per system
- `nix eval .#darwinConfigurations.stud._type` returns `derivation` (or similar evaluation sanity)
**Status**: In Progress

## Stage 2: Modularize host logic
**Goal**: Group and export reusable module sets (`outputs.modules.{nixos,darwin}`) and align `machines/*` to import shared modules by concern (core/workstations/homelab/vps).
**Success Criteria**: `nix eval .#nixosModules` and `.darwinModules` expose expected module sets; one machine migrated to use new module layout.
**Tests**: Evaluate module attributes; build a migrated machine config without errors.
**Status**: Not Started

## Stage 3: Formatter and lint orchestration
**Goal**: Add `treefmt-nix` with `alejandra`, `shfmt`, and `prettier`; wire `statix` and `deadnix` into `checks` via flake-parts.
**Success Criteria**: `nix fmt` formats repo; `nix flake check` runs formatting and static analysis checks.
**Tests**: Run `nix build .#checks.$SYSTEM.*` locally; verify non-zero exit on lint errors.
**Status**: Not Started

## Stage 4: Standardize devShells
**Goal**: Add `numtide/devshell` via flake-parts; define `devShells.default` and role shells (`ops`, `dev`).
**Success Criteria**: `nix develop` drops into a shell with `nix`, `just`, `sops`, and deployment tools available.
**Tests**: `nix develop` works on macOS and Linux; tools are on PATH.
**Status**: Not Started

## Stage 5: CI + FlakeHub integration
**Goal**: Add GitHub Actions for `flake check` and FlakeHub publish on tags.
**Success Criteria**: CI green on PRs; tagged releases published to FlakeHub.
**Tests**: Dry-run CI locally (where possible); verify Action logs on a test tag.
**Status**: Not Started

# Zscaler/Corporate Certificate Management Implementation Plan

## Overview

This implementation adds comprehensive certificate management for macOS systems operating behind corporate proxies like Zscaler. It builds upon the existing corporate network handling to provide system-wide SSL certificate configuration.

## Problem Statement

Corporate networks often use MITM (Man-in-the-Middle) proxies like Zscaler that intercept HTTPS traffic and re-sign it with corporate certificates. This causes SSL verification failures for various tools including:

- Nix package manager operations
- npm/pnpm package installations
- curl/wget requests
- Python requests library
- Homebrew installations

## Solution Architecture

### Stage 1: Core Certificate Management Module ✅ Complete

**Goal**: Create a dedicated Nix module for corporate certificate handling
**Success Criteria**: Module extracts certificates from macOS keychain and configures system-wide environment variables
**Status**: Complete

**Implementation**:
- Created `modules/macos/zscaler.nix` with comprehensive certificate management
- Automatic certificate extraction from multiple macOS keychains
- System-wide environment variable configuration
- Periodic certificate refresh via LaunchDaemon
- Corporate network auto-detection

### Stage 2: Integration with Existing Work Configuration ✅ Complete

**Goal**: Integrate zscaler module with existing work.nix configuration
**Success Criteria**: Seamless integration without breaking existing functionality
**Status**: Complete

**Implementation**:
- Added zscaler.nix import to work.nix
- Configured zscaler module with appropriate settings for corporate environment
- Enhanced pnpm overlay to prefer corporate certificates over TLS bypass
- Maintained backwards compatibility with existing configuration

### Stage 3: Testing and Validation

**Goal**: Verify the implementation works correctly in corporate environment
**Success Criteria**: All tools can successfully make HTTPS requests using corporate certificates
**Status**: Ready for testing

**Test Cases**:
- [ ] `nix flake update` works without SSL errors
- [ ] `pnpm install` works with corporate certificates
- [ ] `curl` commands use corporate certificates
- [ ] Certificate refresh daemon operates correctly
- [ ] Auto-detection correctly identifies corporate environment

### Stage 4: Documentation and Deployment

**Goal**: Document usage and deploy to production systems
**Success Criteria**: Clear documentation and successful deployment
**Status**: In Progress

**Tasks**:
- [ ] Create user documentation
- [ ] Update README with certificate management information
- [ ] Deploy to work laptops
- [ ] Monitor for any issues

## Key Features

### Automatic Certificate Extraction
- Extracts certificates from macOS system keychains
- Handles System.keychain, SystemRootCertificates.keychain, and login.keychain
- Combines all certificates into unified bundle
- Updates symlinks for Nix compatibility

### System-wide Configuration
- Sets comprehensive environment variables:
  - `SSL_CERT_FILE` - Standard SSL certificate file
  - `CURL_CA_BUNDLE` - For curl/wget tools
  - `NODE_EXTRA_CA_CERTS` - For Node.js applications
  - `REQUESTS_CA_BUNDLE` - For Python requests
  - `NIX_SSL_CERT_FILE` - For Nix operations

### Corporate Network Detection
- Automatic detection via multiple methods:
  - Zscaler process detection
  - Proxy environment variables
  - DNS lookups for corporate domains
  - Certificate authority analysis

### Periodic Refresh
- LaunchDaemon for automatic certificate updates
- Configurable refresh interval
- Automatic service restarts when certificates change
- Optional desktop notifications

### Security-First Approach
- Prefers proper certificate validation over TLS bypass
- Falls back to TLS bypass only when certificates unavailable
- Maintains compatibility with Determinate Nix's certificate handling

## Configuration Options

```nix
local.zscaler = {
  enable = true;                    # Enable certificate management
  autoDetect = true;                # Auto-detect corporate environment
  certificatePath = "/path/to/certs"; # Custom certificate bundle path
  refreshInterval = 7200;           # Refresh every 2 hours
  enableNotifications = false;      # Disable notifications in corporate env
};
```

## Integration Points

### Existing Components
- **Determinate Nix**: Handles Nix-specific certificate management automatically
- **pnpm overlay**: Enhanced to use corporate certificates before TLS bypass
- **Corporate network flag**: Used for conditional behavior in other modules

### New Components
- **zscaler.nix module**: Core certificate management functionality
- **Certificate extraction scripts**: Automated keychain export
- **Detection utilities**: Corporate environment identification
- **Refresh daemon**: Periodic certificate updates

## Benefits

1. **Improved Security**: Uses proper certificate validation instead of blanket TLS bypass
2. **System-wide Coverage**: All tools use consistent certificate configuration
3. **Automatic Maintenance**: Certificates update automatically as they change
4. **Backwards Compatibility**: Falls back gracefully when certificates unavailable
5. **Modular Design**: Can be easily enabled/disabled or customized

## Deployment Instructions

1. **Enable the module** in your work configuration:
   ```nix
   imports = [ ./modules/macos/zscaler.nix ];
   local.zscaler.enable = true;
   ```

2. **Apply the configuration**:
   ```bash
   darwin-rebuild switch --flake .#your-hostname
   ```

3. **Verify certificate extraction**:
   ```bash
   sudo extract-corporate-certificates
   ls -la /etc/ssl/nix-corporate/
   ```

4. **Test connectivity**:
   ```bash
   curl -v https://cache.nixos.org
   nix flake update
   ```

## Maintenance

### Manual Certificate Refresh
```bash
refresh-corporate-certificates
```

### Check Corporate Network Status
```bash
detect-corporate-network
```

### View Refresh Logs
```bash
tail -f /var/log/corporate-cert-refresh.log
```

## Troubleshooting

### Common Issues

1. **Permission Errors**: Ensure user has admin privileges for keychain access
2. **Empty Certificate Bundle**: Check that corporate certificates are installed in keychain
3. **Service Not Running**: Verify LaunchDaemon is loaded: `sudo launchctl list | grep corporate-cert`

### Debug Commands

```bash
# Check environment variables
env | grep -E "(SSL_CERT|CERT_FILE|CA_BUNDLE)"

# Test certificate extraction manually
sudo extract-corporate-certificates

# Check if corporate network is detected
detect-corporate-network
```

This implementation provides a robust, automated solution for managing corporate certificates on macOS while maintaining security best practices and backwards compatibility.
