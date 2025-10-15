# Repository Improvement Goals

This document tracks planned improvements for the goodlab NixOS/nix-darwin configuration.

## High Priority

### 1. Update Flake Dependencies

- **Status**: ✅ Completed (2025-10-14)
- **Description**: nixpkgs is outdated (last modified 2025-06-07). Update to latest unstable.
- **Action**: Run `just up` and test builds
- **Impact**: Security patches, newer packages, bug fixes
- **Estimated Effort**: 15 minutes
- **Notes**: Updated to nixpkgs c12c63cd (2025-10-13). Fixed SOPS_AGE_KEY_FILE for Linux systems.

### 2. Add Missing Evaluation Checks

- **Status**: Not Started
- **Description**: Only noir and zinc have eval checks. Missing for vm, iso1chng, iso-aarch64, and all Darwin configs
- **Action**: Add perSystem checks in flake.nix:196-230
- **Impact**: Catch configuration errors in CI before deployment
- **Estimated Effort**: 30 minutes

### 3. Fix Disabled Services

- **Status**: Partially Complete (pdf-intake fix in progress)
- **Description**:
  - ✅ pdf-intake: Already disabled with proper comment about tkinter/tcl bug
  - ⏳ age-gate: Requires nginx Lua module
- **Action**:
  - Monitor nixpkgs for tkinter fix
  - Add nginx with lua module for age-gate
- **Impact**: Enable full Research Relay service stack
- **Estimated Effort**: 2-3 hours

## Medium Priority

### 4. Consolidate Doom Emacs Inputs

- **Status**: ✅ Completed (2025-10-14)
- **Description**: Two doom-emacs inputs in flake.lock (latest 2025-09-30, pinned 2022-09-06)
- **Action**: Verify if pinned version is needed, consolidate to single input
- **Impact**: Reduced complexity, smaller flake.lock
- **Estimated Effort**: 30 minutes
- **Notes**: Removed unused `nix-doom-emacs` input and 17+ transitive dependencies. Reduced flake.lock from 925 → 445 lines (-480 lines, -52%).

### 5. Enhance Impermanence Configuration

- **Status**: ✅ Completed (2025-10-14)
- **Description**: Add missing persistence directories for better system stability
- **Action**: Add to modules/nixos/base.nix:88-127:
  - `/var/lib/systemd` (timers/state)
  - `/var/lib/tailscale` (if using tailscale)
- **Impact**: Prevent state loss across reboots
- **Estimated Effort**: 15 minutes
- **Notes**: Added `/var/lib/systemd` to base NixOS module. `/var/lib/tailscale` already persisted in services/tailscale.nix.

### 6. Add Darwin Configuration Eval Tests

- **Status**: Not Started
- **Description**: No evaluation tests for mair, stud, nblap
- **Action**: Add Darwin-specific checks in flake perSystem
- **Impact**: Catch macOS config errors early
- **Estimated Effort**: 45 minutes

## Low Priority

### 7. Evaluate agenix/ragenix Migration

- **Status**: Not Started
- **Description**: Consider migrating from sops-nix to agenix or ragenix for simpler workflow
- **Action**: Research compatibility, test migration path, document decision
- **Impact**: Potentially simpler key management
- **Estimated Effort**: 3-4 hours (research + testing)

### 8. Expand Justfile with MCP Commands

- **Status**: Not Started
- **Description**: Add package search and info commands using MCP tools
- **Action**: Add to justfile:

  ```justfile
  search query:
    nix search nixpkgs {{query}}

  pkg-info name:
    nix eval nixpkgs#{{name}}.meta.description
  ```

- **Impact**: Faster package discovery workflow
- **Estimated Effort**: 15 minutes

### 9. Documentation Expansion

- **Status**: Not Started
- **Description**: Add missing operational documentation
- **Action**: Document:
  - Disaster recovery for impermanence systems
  - SOPS key rotation procedures
  - Tailscale network topology
  - Service dependency diagram
- **Impact**: Better operational knowledge
- **Estimated Effort**: 2-3 hours

### 10. Flake-parts Optimization

- **Status**: Not Started
- **Description**: Optimize perSystem outputs with conditional builds
- **Action**: Don't build Docker images on Darwin, add cross-compilation targets
- **Example**:
  ```nix
  perSystem = { config, pkgs, system, lib, ... }: {
    packages = lib.optionalAttrs (pkgs.stdenv.isLinux) {
      pdfIntakeImage = ...;
    };
  };
  ```
- **Impact**: Faster eval times, platform-appropriate outputs
- **Estimated Effort**: 1 hour

### 11. State Version Consistency Review

- **Status**: Not Started
- **Description**: Review all machine stateVersion settings for consistency
- **Action**: Audit all configs, document upgrade path if bumping versions
- **Impact**: Consistent state management
- **Estimated Effort**: 30 minutes

### 12. Zscaler Certificate Management Enhancement

- **Status**: Not Started
- **Description**: Improve corporate proxy certificate handling
- **Action**: Add to modules/macos/zscaler.nix:
  - Automatic certificate refresh detection
  - Fallback mechanisms if extraction fails
  - Better corporate network detection
- **Impact**: More robust corporate environment support
- **Estimated Effort**: 2 hours

## Completed

- ✅ **#1 Update Flake Dependencies** (2025-10-14): Updated nixpkgs to c12c63cd, fixed SOPS configuration
- ✅ **#4 Consolidate Doom Emacs Inputs** (2025-10-14): Removed unused nix-doom-emacs, reduced flake.lock by 52%
- ✅ **#5 Enhance Impermanence Configuration** (2025-10-14): Added `/var/lib/systemd` persistence
- ✅ **nixvim Installation** (2025-10-14): Configured nixvim for all devices with comprehensive plugin setup (LSP, Treesitter, Telescope, etc.)
- ✅ **MCP Configuration**: Updated .mcp.json to use `nix run github:utensils/mcp-nixos`
- ✅ **Home Manager SSL Cleanup**: Removed corporate SSL cert paths from base config (commit 60e32e5)

---

**Last Updated**: 2025-10-14
**Total Items**: 13 improvements (6 complete, 7 pending)
