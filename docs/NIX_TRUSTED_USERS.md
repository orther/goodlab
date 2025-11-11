# Nix Trusted Users Configuration

This document explains the "ignoring untrusted substituter" warning and how to fix it.

## Problem

When building with Nix, you may see warnings like:

```
warning: ignoring untrusted substituter 'https://orther.cachix.org', you are not a trusted user.
warning: ignoring untrusted substituter 'https://devenv.cachix.org', you are not a trusted user.
```

## Root Cause

Nix only allows **trusted users** to use custom binary cache substituters. This is a security feature to prevent untrusted users from specifying malicious binary caches.

## Solution by Platform

### NixOS

Configure `nix.settings.trusted-users` in your NixOS configuration:

```nix
# modules/nixos/base.nix
nix.settings.trusted-users = [
  "root"
  "@wheel"  # All users in the wheel group
];
```

After deploying, the change takes effect immediately (systemd restarts nix-daemon automatically).

### macOS with Determinate Nix

Determinate Nix manages `/etc/nix/nix.conf` and provides `/etc/nix/nix.custom.conf` for user modifications.

**Option 1: Use provided script (recommended)**

```bash
sudo ./scripts/setup-nix-trusted-users.sh
sudo launchctl kickstart -k system/systems.determinate.nix-daemon
```

**Option 2: Manual configuration**

Add to `/etc/nix/nix.custom.conf`:

```conf
# Allow admin users to use custom substituters
trusted-users = root @admin
```

Then restart the Nix daemon:

```bash
sudo launchctl kickstart -k system/systems.determinate.nix-daemon
```

### macOS with nix-darwin (non-Determinate)

Configure in your nix-darwin configuration:

```nix
# modules/macos/base.nix
nix.settings.trusted-users = [
  "root"
  "@admin"  # All users in the admin group
];
```

Apply with `darwin-rebuild switch`.

## Verification

After configuration, test with a simple build:

```bash
# Should see no "untrusted substituter" warnings
nix build .#nixosConfigurations.noir.config.system.build.toplevel --dry-run
```

## Security Implications

**Important**: Adding a user to `trusted-users` grants them the ability to:

- Use any binary cache substituter (custom or official)
- Perform other privileged Nix operations
- Bypass certain security checks

Only add trusted users or groups (like `@wheel` or `@admin`) that you control.

## References

- [Nix Manual: trusted-users](https://nixos.org/manual/nix/stable/command-ref/conf-file.html#conf-trusted-users)
- [NixOS Discourse: ignoring untrusted substituter](https://discourse.nixos.org/t/ignoring-untrusted-substituter/)
- [Determinate Nix Documentation](https://docs.determinate.systems/)

## Troubleshooting

**Warning persists after configuration**

- Ensure Nix daemon was restarted
- Verify user is in the specified group (`groups` command)
- Check configuration was actually applied (`cat /etc/nix/nix.conf` or `nix show-config | grep trusted-users`)

**Changes not taking effect**

- On macOS: Restart terminal and Nix daemon
- On NixOS: Rebuild and switch configuration
- Verify no syntax errors in configuration files
