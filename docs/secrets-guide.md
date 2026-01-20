# Secrets Management Guide

This guide explains how secrets (passwords, API keys, tokens) are securely managed in this NixOS/nix-darwin repository.

## Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           SECRETS ARCHITECTURE                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   secrets/secrets.yaml          .sops.yaml              /nix/secret/        │
│   ┌──────────────────┐         ┌─────────────┐         ┌──────────────┐    │
│   │ user-password:   │         │ keys:       │         │ initrd/      │    │
│   │   ENC[AES256...] │◄───────►│  - &nblap   │◄────────│  ssh_host_*  │    │
│   │ tailscale-key:   │  encrypts│  - &noir    │ derived │              │    │
│   │   ENC[AES256...] │         │  - &stud    │  from   └──────────────┘    │
│   │ cloudflare-*:    │         │  - &zinc    │                              │
│   │   ENC[AES256...] │         │  - &pie     │                              │
│   └──────────────────┘         └─────────────┘                              │
│            │                                                                 │
│            │ decrypted at boot by sops-nix                                  │
│            ▼                                                                 │
│   ┌──────────────────────────────────────────────────────────────────┐     │
│   │                    /run/secrets/                                  │     │
│   │  user-password ─► /run/secrets-for-users/user-password           │     │
│   │  tailscale-key ─► /run/secrets/tailscale-authkey                 │     │
│   │  cloudflare-*  ─► /run/secrets/cloudflare-api-key                │     │
│   └──────────────────────────────────────────────────────────────────┘     │
│            │                                                                 │
│            │ used by                                                        │
│            ▼                                                                 │
│   ┌──────────────────────────────────────────────────────────────────┐     │
│   │  NixOS Services & Users                                          │     │
│   │  • users.users.orther.hashedPasswordFile                         │     │
│   │  • services.tailscale (authkey)                                  │     │
│   │  • services.cloudflared (tunnel credentials)                     │     │
│   └──────────────────────────────────────────────────────────────────┘     │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Key Concepts

### 1. SOPS + Age Encryption

We use **SOPS** (Secrets OPerationS) with **Age** encryption:

| Tool | Purpose |
|------|---------|
| **SOPS** | Encrypts/decrypts YAML files, manages multiple recipients |
| **Age** | Modern encryption tool (replaces GPG), uses simple public/private keys |
| **sops-nix** | NixOS module that decrypts secrets at boot time |

### 2. Key Derivation from SSH Host Keys

Each machine's Age key is **derived from its SSH host key**:

```
SSH Host Key (ed25519)              Age Public Key
/nix/secret/initrd/
  ssh_host_ed25519_key      ───►    age1abc123...
  ssh_host_ed25519_key.pub

Conversion command:
$ ssh-to-age < /nix/secret/initrd/ssh_host_ed25519_key.pub
age1pq6uyy9fp43pyxqu9unxjg6nuhuln8psl2lx0exrlpt4ec2s8sgqay5aya
```

**Why this approach?**
- SSH host keys are already unique per machine
- No need to generate/manage separate Age keys
- Keys are created during installation (before secrets exist)

### 3. Two Types of Secrets

| Type | When Needed | Storage Location | Managed By |
|------|-------------|------------------|------------|
| **Regular Secrets** | After boot | `secrets/secrets.yaml` | SOPS + sops-nix |
| **Early Boot Secrets** | During initrd | `/nix/secret/initrd/` | Manual (persist) |

## File Structure

```
goodlab/
├── .sops.yaml                    # Key configuration (who can decrypt)
├── secrets/
│   └── secrets.yaml              # Encrypted secrets file
└── /nix/secret/                  # On each machine (not in repo)
    └── initrd/
        ├── ssh_host_ed25519_key  # Private key (decryption)
        └── ssh_host_ed25519_key.pub
```

## How Secrets Flow

### At Build Time (nix build)

```
secrets/secrets.yaml is copied to /nix/store (still encrypted)
                     ─────────────────────────────────────────►
                     Secrets are NEVER decrypted during build
```

### At Boot Time (NixOS activation)

```
1. System boots
2. sops-nix reads /nix/secret/initrd/ssh_host_ed25519_key
3. sops-nix decrypts secrets/secrets.yaml
4. Secrets written to /run/secrets/* (tmpfs, RAM-only)
5. Services start and read their secrets
```

### Secret Lifecycle

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Encrypted  │     │   Stored    │     │  Decrypted  │     │   Used by   │
│  in repo    │────►│  in /nix/   │────►│  at boot    │────►│  services   │
│  (safe)     │     │  store      │     │  to tmpfs   │     │             │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
     YAML              (encrypted)        /run/secrets/      hashedPasswordFile
   committed            immutable          RAM only           API tokens, etc.
```

## Configuration

### .sops.yaml - Who Can Decrypt

```yaml
keys:
  # Each machine's Age public key (derived from SSH host key)
  - &nblap age1pq6uyy9fp43pyxqu9unxjg6nuhuln8psl2lx0exrlpt4ec2s8sgqay5aya
  - &noir age1hychfwplt2rpkzdxvz5lxy7zjf0dt0y6qrcwe2gvnm4mkelsnc7syu2y25
  - &stud age1gz6jjmdce0xjh4c8st4tx5qhd5lpw2527dzfr6davwpjyrrr8ctqnv3p4z
  - &zinc age12pc2l7dyq0tlj0mm56vrwez6yr8nlve6vrucexf7x92dg7qlzcxskrf2tv
  - &pie age1...  # Added after machine installation

creation_rules:
  # All secrets encrypted to all machines
  - path_regex: secrets/[^/]+(\.(yaml|json|env|ini|conf))?$
    key_groups:
      - age:
          - *nblap
          - *noir
          - *stud
          - *zinc
          - *pie
```

### modules/nixos/base.nix - SOPS Configuration

```nix
sops = {
  # Default encrypted file location
  defaultSopsFile = ./../../secrets/secrets.yaml;

  # Where to find the decryption key
  age.sshKeyPaths = ["/nix/secret/initrd/ssh_host_ed25519_key"];

  # Secrets to decrypt (makes them available at /run/secrets/*)
  secrets."user-password".neededForUsers = true;
  secrets."user-password" = {};

  # Disable GPG (we only use Age)
  gnupg.sshKeyPaths = [];
};

# Use decrypted password for user
users.users.orther = {
  hashedPasswordFile = config.sops.secrets."user-password".path;
};
```

## Early Boot Secrets (Initrd)

Some secrets are needed **before** the main system boots - SOPS can't help here because the decryption happens during activation, not initrd.

### Use Case: Remote LUKS Unlock

For servers with encrypted disks, you may want to SSH in during boot to enter the LUKS passphrase:

```nix
# modules/nixos/remote-unlock.nix
{
  boot.initrd.network = {
    enable = true;
    ssh = {
      enable = true;
      shell = "/bin/cryptsetup-askpass";
      # Uses the SAME key as sops-nix
      hostKeys = ["/nix/secret/initrd/ssh_host_ed25519_key"];
      authorizedKeys = config.users.users.orther.openssh.authorizedKeys.keys;
    };
  };
}
```

### How Early Boot Keys Are Stored

```
/nix/secret/initrd/           # Persistent directory (survives reboot)
├── ssh_host_ed25519_key      # Used by: initrd SSH, sops-nix decryption
└── ssh_host_ed25519_key.pub

This path is:
• Outside /nix/store (not world-readable)
• Persisted across reboots (on /nix partition)
• Created during installation (before secrets exist)
```

## Adding a New Machine

### Step 1: Generate SSH Host Keys (during installation)

```bash
sudo ssh-keygen -t ed25519 -f /mnt/nix/secret/initrd/ssh_host_ed25519_key -N ""
```

### Step 2: Get the Age Public Key

```bash
nix-shell -p ssh-to-age --run "ssh-to-age < /mnt/nix/secret/initrd/ssh_host_ed25519_key.pub"
# Output: age1abc123...
```

### Step 3: Add to .sops.yaml

```yaml
keys:
  - &newmachine age1abc123...  # Add this line

creation_rules:
  - path_regex: secrets/...
    key_groups:
      - age:
          - *newmachine  # Add this reference
```

### Step 4: Re-encrypt Secrets

```bash
sops updatekeys secrets/secrets.yaml
```

### Step 5: Commit and Deploy

```bash
git add .sops.yaml secrets/secrets.yaml
git commit -m "feat: add newmachine to sops secrets"
git push
```

## Working with Secrets

### View/Edit Secrets

```bash
# Edit secrets (decrypts in $EDITOR, re-encrypts on save)
sops secrets/secrets.yaml

# Or use the just command
just sopsedit
```

### Add a New Secret

```bash
# Open in editor
sops secrets/secrets.yaml

# Add your secret
my-new-secret: "super-secret-value"

# Save and close - automatically encrypted
```

### Use Secret in NixOS Config

```nix
# In configuration.nix or a module
{
  sops.secrets."my-new-secret" = {
    owner = "myservice";  # Optional: set file owner
    group = "myservice";  # Optional: set file group
    mode = "0400";        # Optional: set permissions
  };

  # Reference the decrypted file path
  services.myservice.configFile = config.sops.secrets."my-new-secret".path;
}
```

## Security Model

### What's Protected

| Threat | Protection |
|--------|------------|
| Secrets in git repo | Encrypted with Age (only machines can decrypt) |
| Secrets at rest on disk | Encrypted in /nix/store, decrypted only to tmpfs |
| Secrets in memory | Only in RAM (/run/secrets is tmpfs) |
| Unauthorized machines | Can't decrypt without private key |

### What's NOT Protected

| Threat | Mitigation |
|--------|------------|
| Root on the machine | Root can read /run/secrets - this is by design |
| Compromise of SSH host key | Rotate key, re-encrypt secrets |
| Secrets in service memory | Out of scope for secret management |

## Troubleshooting

### "Permission denied" decrypting secrets

```bash
# Check the SSH key exists and is readable
ls -la /nix/secret/initrd/ssh_host_ed25519_key

# Verify key matches .sops.yaml
nix-shell -p ssh-to-age --run "ssh-to-age < /nix/secret/initrd/ssh_host_ed25519_key.pub"
# Compare output with .sops.yaml
```

### Secrets not available after boot

```bash
# Check sops-nix service status
systemctl status sops-nix

# Check if secrets directory exists
ls -la /run/secrets/

# Check sops-nix logs
journalctl -u sops-nix
```

### "MAC mismatch" or decryption errors

The machine's key isn't in the encrypted file's recipient list:

```bash
# On a machine that CAN decrypt, update the keys
sops updatekeys secrets/secrets.yaml
```

## Quick Reference

| Task | Command |
|------|---------|
| Edit secrets | `just sopsedit` or `sops secrets/secrets.yaml` |
| Update keys for all machines | `just sopsupdate` |
| Rotate keys | `just sopsrotate` |
| Get age key from SSH key | `ssh-to-age < /path/to/key.pub` |
| Check secret path in NixOS | `config.sops.secrets."name".path` |

## Further Reading

- [sops-nix GitHub](https://github.com/Mic92/sops-nix)
- [Age encryption](https://github.com/FiloSottile/age)
- [SOPS](https://github.com/getsops/sops)
