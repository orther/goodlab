# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Essential Commands

### Development Workflow

```bash
# Format repository (uses treefmt with alejandra, shfmt, prettier)
nix fmt

# Run all checks (formatting, statix, deadnix, eval tests)
nix flake check

# Enter development shell with tools (git, just, sops, etc.)
nix develop

# Enter ops shell with deployment tools
nix develop .#ops

# Update flake dependencies
just up
```

### Deployment

```bash
# Deploy to macOS machine (stud, mair, nblap)
just deploy <hostname>

# Deploy to NixOS machine locally
just deploy <hostname>

# Deploy to remote NixOS machine
just deploy <hostname> <ip-address>

# Examples:
just deploy stud           # Deploy to local macOS (Apple Silicon)
just deploy mair          # Deploy to local macOS (Intel)
just deploy noir 10.0.10.2 # Deploy to remote NixOS server
```

### Local Development Services

```bash
# Start services (PostgreSQL on 5432, Redis on 6379)
nix run .#devservices

# Stop services
nix run .#devservices -- stop
```

### Secrets Management

```bash
# Edit secrets file
just sopsedit

# Update SOPS keys for all machines
just sopsupdate

# Rotate SOPS keys
just sopsrotate
```

### Maintenance

```bash
# Lint Nix code
just lint

# Garbage collection
just gc

# Repair Nix store
just repair

# Build custom ISO
just build-iso
```

## Architecture Overview

### Repository Structure

This is a **Nix flakes-based homelab configuration** using modern flake orchestration with flake-parts. The repository manages:

- **macOS workstations** (Apple Silicon and Intel) via nix-darwin
- **NixOS servers** (homelab and VPS) with impermanence (root on tmpfs)
- **WSL environments** for development
- **Custom ISO builds** for installations

### Key Technologies

- **Flake-parts**: Modern flake structure with perSystem outputs
- **Home Manager**: Dotfiles and user environment management
- **SOPS-nix**: Age-encrypted secrets management
- **Impermanence**: Ephemeral root filesystem with persistent data
- **Services-flake**: Development service orchestration (Postgres, Redis)
- **Treefmt**: Unified formatting across file types

### Machine Categories

#### Darwin (macOS)

- `stud`: Apple Silicon MacBook (personal)
- `mair`: Intel MacBook (personal)
- `nblap`: Apple Silicon MacBook (work)

#### NixOS (Linux)

- `noir`: Homelab server (x86_64)
- `zinc`: Homelab server (x86_64)
- `vm`: Test VM (aarch64)

#### Special Configurations

- `iso1chng`: Custom NixOS installation ISO
- Various template machines for different deployment scenarios

### Module Organization

#### Core Module Types

```
modules/
├── nixos/           # NixOS system modules
│   ├── base.nix     # Common NixOS configuration
│   ├── desktop.nix  # Desktop environment setup
│   └── remote-unlock.nix # Remote SSH unlock for encrypted drives
├── macos/           # Darwin/macOS modules
│   ├── base.nix     # Common macOS configuration
│   ├── work.nix     # Corporate environment setup
│   └── zscaler.nix  # Corporate proxy certificate management
├── home-manager/    # User environment modules
│   ├── base.nix     # Common user configuration
│   ├── fonts.nix    # Font management
│   └── doom.nix     # Doom Emacs configuration
└── wsl/            # Windows Subsystem for Linux
    └── base.nix     # WSL-specific configuration
```

#### Modular Design Pattern

The configuration follows a **composition-based module system**:

1. **Base modules** provide fundamental system configuration
2. **Specialized modules** add specific functionality (desktop, corporate networking)
3. **Machine configurations** compose modules based on use case
4. **Exported module sets** enable reuse across machines and downstream flakes

### Service Architecture

#### Self-hosted Services (services/)

```
services/
├── nas.nix          # File sharing and storage
├── tailscale.nix    # VPN mesh networking
├── nextcloud.nix    # Cloud storage and collaboration
├── jellyfin.css     # Media server styling
└── nixarr.nix       # Media acquisition stack
```

#### Development Services

- **PostgreSQL**: Database for local development
- **Redis**: Caching and session storage
- **Process-compose**: Service orchestration via services-flake

### Security and Secrets

#### SOPS Integration

- **Age encryption** with machine-specific keys
- **Automatic key rotation** and update workflows
- **Per-environment secrets** (development, staging, production)
- **Corporate certificate management** for proxy environments

#### Remote Access

- **SSH key-based authentication** only
- **Remote unlock** capability for encrypted drives
- **Tailscale mesh networking** for secure remote access

## Development Patterns

### Configuration Conventions

- **Immutable systems**: NixOS with impermanence, reproducible macOS setups
- **Declarative secrets**: All secrets managed through SOPS, no imperative configuration
- **Module composition**: Prefer small, focused modules over monolithic configurations
- **Cross-platform consistency**: Shared patterns between Darwin and NixOS where possible

### Testing Strategy

- **Evaluation checks**: Lightweight smoke tests via `nix flake check`
- **Static analysis**: `statix` for Nix best practices, `deadnix` for unused code
- **Formatting validation**: Automated via treefmt in CI
- **Machine-specific validation**: Per-host evaluation tests prevent regressions

### Deployment Philosophy

- **Incremental deployment**: Small, atomic changes over big-bang updates
- **Environment-specific configuration**: Development, homelab, and production variants
- **Automated updates**: Daily `flake.lock` updates via GitHub Actions
- **Rollback capability**: systemd-boot generations for easy recovery

## Corporate Environment Support

### Zscaler/Proxy Integration

The repository includes comprehensive support for corporate environments with MITM proxies:

- **Automatic certificate extraction** from macOS keychain
- **System-wide SSL configuration** for all development tools
- **Corporate network detection** with automatic activation
- **Periodic certificate refresh** to handle rotations

### Work Machine Configuration

Work machines (`nblap`) include:

- Corporate proxy certificate management
- Enhanced security policies
- Integration with corporate authentication systems
- Compatibility with enterprise software requirements

## Troubleshooting

### Common Issues

1. **Build failures**: Run `nix flake check` to identify issues before deployment
2. **Secret decryption**: Ensure SOPS keys are properly configured for the target machine
3. **Network connectivity**: Corporate environments may require certificate configuration
4. **SSH access**: Verify SSH keys are properly deployed for remote operations

### Debug Commands

```bash
# Check flake evaluation
nix eval .#nixosConfigurations.<machine>.config.system.stateVersion

# Test secret decryption
sops -d secrets/secrets.yaml

# Verify SSH connectivity
ssh orther@<machine-ip> "sudo nixos-rebuild --version"

# Check service status
systemctl status tailscaled
```

### Recovery Procedures

- **Boot into previous generation** via systemd-boot menu
- **Emergency SSH access** via remote unlock keys
- **Manual certificate extraction** for corporate environment issues
- **Flake rollback** using `git` history for configuration recovery

## Integration Points

### External Dependencies

- **FlakeHub**: Dependency management and binary caching
- **GitHub Actions**: CI/CD pipeline for testing and releases
- **Tailscale**: Mesh networking for secure remote access
- **SOPS**: Age-based secret encryption

### Development Tools Integration

- **Age/SOPS**: Secret management throughout the configuration
- **Just**: Task runner for common operations (alternative to complex makefiles)
- **Treefmt**: Unified code formatting across Nix, shell, and markdown files
- **Services-flake**: Reproducible development environments

This configuration represents a **production-ready homelab setup** that balances security, reproducibility, and operational simplicity while supporting both personal and corporate environments.
