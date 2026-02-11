# NixOS Configuration Plan for OpenClaw VPS

## Overview

This document details the NixOS configuration for the new `lildoofy` VPS, following established patterns from `noir`, `zinc`, and `pie` in this repository.

Isolation baseline for this host:
- No reuse of personal auth/session credentials
- No shared secret recipient fanout across unrelated hosts
- No public ingress except what is explicitly required
- No tailnet route advertisement from the bot VPS

## Host Configuration

### `hosts/lildoofy/default.nix`

```nix
{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  ...
}: {
  imports = [
    inputs.impermanence.nixosModules.impermanence
    inputs.home-manager.nixosModules.home-manager
    inputs.nix-clawdbot.nixosModules.clawdbot

    ./hardware-configuration.nix

    inputs.self.nixosModules.base
    inputs.self.nixosModules."auto-update"

    ./../../services/openclaw.nix
    ./../../services/ollama.nix
  ];

  home-manager = {
    extraSpecialArgs = {inherit inputs outputs;};
    useGlobalPkgs = true;
    useUserPackages = true;
    users = {
      orther = {...}: {
        imports = [
          inputs.self.lib.hmModules.server-base
        ];

        programs.git = {
          enable = true;
          settings = {
            user = {
              name = "Brandon Orther";
              email = "brandon@orther.dev";
            };
          };
        };
      };
    };
  };

  # --- SOPS Secrets ---
  # Keep lildoofy isolated from shared repo secrets.
  sops.defaultSopsFile = ./../../secrets/lildoofy-secrets.yaml;

  sops.secrets."tailscale-authkey" = {};
  sops.secrets."clawdbot/telegram-bot-token" = {
    owner = "clawdbot";
    group = "clawdbot";
    mode = "0400";
  };
  sops.secrets."clawdbot/openrouter-api-key" = {
    owner = "clawdbot";
    group = "clawdbot";
    mode = "0400";
  };
  sops.secrets."clawdbot/anthropic-oauth-token" = {
    owner = "clawdbot";
    group = "clawdbot";
    mode = "0400";
  };
  sops.secrets."clawdbot/gateway-token" = {
    owner = "clawdbot";
    group = "clawdbot";
    mode = "0400";
  };
  sops.secrets."clawdbot/brave-search-api-key" = {
    owner = "clawdbot";
    group = "clawdbot";
    mode = "0400";
  };
  # Important: all secret values above should be dedicated to this bot runtime.
  # Do not reuse personal OAuth/session tokens from your daily accounts.

  # --- OpenClaw Service ---
  services.clawdbot = {
    enable = true;
    documents = ./../../clawdbot-documents;

    instances.default = {
      enable = true;

      providers.telegram = {
        enable = true;
        botTokenFile = config.sops.secrets."clawdbot/telegram-bot-token".path;
        allowFrom = [5875599249];
        groups = {
          "*" = {requireMention = true;};
        };
      };

      providers.anthropic = {
        oauthTokenFile = config.sops.secrets."clawdbot/anthropic-oauth-token".path;
      };

      gateway.auth = {
        mode = "token";
        tokenFile = config.sops.secrets."clawdbot/gateway-token".path;
      };

      configOverrides = {
        gateway.bind = "lan";

        # Token optimization: model routing
        models = {
          default = "haiku";
          aliases = {
            haiku = "claude-3-5-haiku-latest";
            sonnet = "claude-sonnet-4-20250514";
          };
        };

        # Token optimization: session initialization
        session = {
          initialFiles = ["SOUL.md" "USER.md" "IDENTITY.md"];
          dailyMemory = true;
          autoLoadHistory = false;
        };

        # Token optimization: heartbeat to local Ollama
        heartbeat = {
          provider = "ollama";
          endpoint = "http://127.0.0.1:11434";
          model = "llama3.2:3b";
          interval = 60;
        };

        # Token optimization: budget controls
        budget = {
          daily = 5;
          monthly = 200;
          warnAt = 0.75;
        };

        # Web tools
        tools.web = {
          search = {
            enabled = true;
            provider = "brave";
          };
          fetch.enabled = true;
        };
      };

      plugins = [];
    };
  };

  # --- Brave Search API key injection ---
  systemd.services.clawdbot-brave-env = {
    description = "Inject Brave Search API key into Clawdbot config";
    before = ["clawdbot-gateway.service"];
    requiredBy = ["clawdbot-gateway.service"];
    after = ["sops-nix.service"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "inject-brave-key" ''
        set -euo pipefail
        key_file="${config.sops.secrets."clawdbot/brave-search-api-key".path}"
        config_file="/var/lib/clawdbot/clawdbot.json"

        if [ -f "$key_file" ] && [ -f "$config_file" ]; then
          api_key="$(cat "$key_file")"
          ${pkgs.gnused}/bin/sed -i \
            -e 's|,"apiKey":"[^"]*"||g' \
            -e "s|\"provider\":\"brave\"|\"provider\":\"brave\",\"apiKey\":\"$api_key\"|" \
            "$config_file"
        fi
      '';
    };
  };

  # --- Networking ---
  services.openssh.openFirewall = lib.mkForce false;
  services.tailscale = {
    enable = true;
    authKeyFile = config.sops.secrets."tailscale-authkey".path;
    openFirewall = false;
    # Client mode only: do not advertise homelab routes from lildoofy.
    useRoutingFeatures = "client";
    extraUpFlags = ["--accept-dns=true"];
  };

  networking = {
    hostName = "lildoofy";
    useDHCP = true;
    useNetworkd = true;
    networkmanager.enable = lib.mkForce false;

    firewall = {
      enable = true;
      allowedTCPPorts = [];
      # SSH + gateway accessible only over Tailscale.
      interfaces.tailscale0.allowedTCPPorts = [22 18789];
    };
  };

  # --- Disable wait-online services ---
  systemd.services = {
    "NetworkManager-wait-online".enable = lib.mkForce false;
    "systemd-networkd-wait-online".enable = lib.mkForce false;
  };
}
```

### `hosts/lildoofy/hardware-configuration.nix`

This file will be generated by `nixos-anywhere` / `disko` during installation. Template for Hetzner Cloud:

```nix
{config, lib, modulesPath, ...}: {
  imports = [(modulesPath + "/profiles/qemu-guest.nix")];

  boot = {
    loader.grub = {
      efiSupport = true;
      efiInstallAsRemovable = true;
    };
    initrd.availableKernelModules = [
      "ata_piix"
      "uhci_hcd"
      "virtio_pci"
      "virtio_scsi"
      "sd_mod"
      "sr_mod"
    ];
  };

  # Disk layout comes from disko-config.nix.
  # Do not pin /dev/sdX mappings here; let disko own filesystem definitions.

  swapDevices = [];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
```

**Note:** Keep filesystem definitions in disko config to avoid drift and wrong-device boot failures.

## Service Modules

### `services/ollama.nix`

```nix
{config, pkgs, lib, ...}: {
  # Ollama — local LLM inference for OpenClaw heartbeats
  services.ollama = {
    enable = true;
    host = "127.0.0.1";
    port = 11434;
    loadModels = ["llama3.2:3b"];
  };

  # Persist model data across reboots (impermanence)
  environment.persistence."/nix/persist" = {
    directories = [
      {
        directory = "/var/lib/ollama";
        user = "ollama";
        group = "ollama";
        mode = "0700";
      }
    ];
  };
}
```

### `services/openclaw.nix` (Optional Refactor)

If we want a reusable service module (rather than inline config in the host), extract the common OpenClaw patterns:

```nix
# Reusable OpenClaw/Clawdbot service configuration helpers.
# The actual nix-clawdbot NixOS module is imported via flake input.
# This file provides shared patterns for configuring it.
{config, pkgs, lib, ...}: {
  # Ensure Docker is available for OpenClaw's sandbox
  virtualisation.docker = {
    enable = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };

  # Persist clawdbot state across reboots (impermanence)
  environment.persistence."/nix/persist" = {
    directories = [
      {
        directory = "/var/lib/clawdbot";
        user = "clawdbot";
        group = "clawdbot";
        mode = "0750";
      }
    ];
  };
}
```

## Flake Changes

### `flake.nix` additions

Add to `nixosConfigurations`:

```nix
lildoofy = nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";
  specialArgs = {
    inherit inputs;
    inherit (self) outputs;
  };
  modules = [
    ./hosts/lildoofy/default.nix
    {
      nixpkgs.overlays = [
        inputs.nix-clawdbot.overlays.default
      ];
    }
  ];
};
```

Add to `checks` (inside `perSystem`):

```nix
nixosEval-lildoofy = let
  sys = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = {
      inherit inputs;
      inherit (self) outputs;
    };
    modules = [./hosts/lildoofy/default.nix];
  };
  summary = builtins.toJSON {
    platform = sys.pkgs.stdenv.hostPlatform.system;
    stateVersion = sys.config.system.stateVersion or null;
  };
in
  pkgs.writeText "nixos-eval-lildoofy.json" summary;
```

## SOPS Changes

### `.sops.yaml`

Add the new machine's age key and scope it to a dedicated secrets file. Rule order matters: put the `lildoofy` rule before the shared catch-all rule.

```yaml
keys:
  - &noir age1hychfwplt2rpkzdxvz5lxy7zjf0dt0y6qrcwe2gvnm4mkelsnc7syu2y25
  - &stud age1gz6jjmdce0xjh4c8st4tx5qhd5lpw2527dzfr6davwpjyrrr8ctqnv3p4z
  - &zinc age12pc2l7dyq0tlj0mm56vrwez6yr8nlve6vrucexf7x92dg7qlzcxskrf2tv
  - &vm age1aruj7g3pugj3knq2f5u02tzq6vu5edcjv25veudrsvtr2yzedpusssscpz
  - &pie age1kxs72nkpe55uc0zv9jrtme8nsr97r74vjrfs2sccwkfxe7lnzvrs6n2v87
  - &lildoofy age1XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
creation_rules:
  - path_regex: secrets/lildoofy-secrets\.yaml$
    key_groups:
      - age:
          - *stud
          - *lildoofy
  - path_regex: secrets/[^/]+(\.(yaml|json|env|ini|conf))?$
    key_groups:
      - age:
          - *noir
          - *stud
          - *zinc
          - *vm
          - *pie
```

The actual age key is derived from the VPS SSH host key after installation:
```bash
ssh orther@<lildoofy-ip> "sudo cat /etc/ssh/ssh_host_ed25519_key.pub" | ssh-to-age
```

## Disko Configuration (for nixos-anywhere)

For automated disk partitioning during `nixos-anywhere` install:

```nix
# disko-config.nix — used only during initial installation
{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/sda"; # Hetzner primary disk
        content = {
          type = "gpt";
          partitions = {
            boot = {
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/nix";
              };
            };
          };
        };
      };
    };
    nodev = {
      "/" = {
        fsType = "tmpfs";
        mountOptions = ["defaults" "size=2G" "mode=0755"];
      };
    };
  };
}
```

## nixos-anywhere Deployment Command

```bash
# From a machine with SSH access to the VPS
# Ensure SSH for <hetzner-ip> uses ~/.ssh/lildoofy_admin_ed25519
nix run github:nix-community/nixos-anywhere -- \
  --flake .#lildoofy \
  --disko-mode disko \
  root@<hetzner-ip>
```

## Clawdbot Documents Updates

### Updated `clawdbot-documents/AGENTS.md`

```markdown
# Agent Configuration

You are **Lil Doofy**, a personal AI assistant for Brandon running on a NixOS VPS (lildoofy).

## Personality

- Concise in chat — Telegram messages should be scannable, not essays
- Technically proficient — you're talking to a software engineer
- Proactive when useful — suggest follow-ups, flag potential issues
- Honest about uncertainty — say "I'm not sure" rather than guessing
- Cost-conscious — prefer Haiku for simple tasks

## Response Style

- Default to short, direct answers
- Use code blocks for commands, configs, and structured data
- Use bullet points for lists of items
- Only go long-form when explicitly asked to explain or elaborate
- Use markdown formatting (Telegram supports it)

## Context

- Brandon works with Nix/NixOS, Go, TypeScript, and Rust
- The homelab runs on NixOS with impermanence, SOPS secrets, and Tailscale
- Infrastructure is managed as code in a flake-based repository called "goodlab"
- This bot runs on a Hetzner Cloud VPS named "lildoofy"
- Primary messaging channel is Telegram
```

## Deployment Checklist

1. [ ] Provision Hetzner CX33 VPS
2. [ ] Run nixos-anywhere with disko config
3. [ ] Verify SSH access to NixOS
4. [ ] Extract age key, add to `.sops.yaml`
5. [ ] Create `secrets/lildoofy-secrets.yaml` and run `just sopsupdate`
6. [ ] Create `hosts/lildoofy/` directory with configs
7. [ ] Add `lildoofy` to `flake.nix`
8. [ ] Create `services/ollama.nix`
9. [ ] Create `services/openclaw.nix` (optional refactor)
10. [ ] Run `nix flake check` — verify eval passes
11. [ ] Deploy: `just deploy lildoofy <ip>`
12. [ ] Verify Telegram bot responds
13. [ ] Verify Ollama heartbeats in logs
14. [ ] Add new clawdbot-documents (USER.md, IDENTITY.md)
15. [ ] Enable token optimizations in configOverrides
16. [ ] Monitor API costs for 1 week
17. [ ] Disable clawdbot on `noir`
18. [ ] Rotate old `noir` bot credentials after cutover
19. [ ] Set up backups for `/var/lib/clawdbot` and `/var/lib/ollama`
