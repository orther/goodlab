# lildoofy - Hetzner Cloud VPS for OpenClaw (Alexandra Morgan bot)
# Isolation: dedicated credentials, Tailscale-only ingress, no route advertisement
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
    inputs.nix-openclaw.nixosModules.openclaw-gateway

    ./hardware-configuration.nix

    inputs.self.nixosModules.base
    inputs.self.nixosModules."auto-update"

    ./../../services/openclaw.nix
    ./../../services/ollama.nix
  ];

  # --- OpenClaw User/Group (created early for impermanence/SOPS) ---
  # The module creates 'openclaw' user, but we declare it here so it exists
  # before impermanence and SOPS activation scripts run
  users.users.openclaw = {
    isSystemUser = true;
    group = "openclaw";
    home = "/var/lib/openclaw";
    createHome = true;
  };
  users.groups.openclaw = {};

  # --- SSH Access ---
  # Add the dedicated lildoofy admin key alongside the personal key from base.nix
  users.users.orther.openssh.authorizedKeys.keys = [
    # lildoofy_admin_ed25519.pub - dedicated admin key for this VPS
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIODzc3LPRHmaxwPf5Exc6mrFs8tCcl6p3QKXz6mDuIB/ lildoofy-admin"
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

  # --- Boot Loader Override ---
  # base.nix enables systemd-boot + EFI, but Hetzner Cloud uses BIOS boot
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

  # --- SOPS Override ---
  # base.nix sets sops.age.sshKeyPaths to the LUKS initrd key path.
  # lildoofy has no LUKS, so override to the standard SSH host key.
  sops.age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];

  # Keep lildoofy isolated from shared repo secrets
  sops.defaultSopsFile = lib.mkForce ./../../secrets/lildoofy-secrets.yaml;

  # user-password is required by base.nix for hashedPasswordFile
  sops.secrets."user-password" = {};
  sops.secrets."tailscale-authkey" = {};
  sops.secrets."openclaw/telegram-bot-token" = {
    owner = "openclaw";
    group = "openclaw";
    mode = "0400";
  };
  sops.secrets."openclaw/openrouter-api-key" = {
    owner = "openclaw";
    group = "openclaw";
    mode = "0400";
  };
  sops.secrets."openclaw/anthropic-oauth-token" = {
    owner = "openclaw";
    group = "openclaw";
    mode = "0400";
  };
  sops.secrets."openclaw/gateway-token" = {
    owner = "openclaw";
    group = "openclaw";
    mode = "0400";
  };
  sops.secrets."openclaw/brave-search-api-key" = {
    owner = "openclaw";
    group = "openclaw";
    mode = "0400";
  };

  # --- OpenClaw Service (main branch module) ---
  services.openclaw-gateway = {
    enable = true;
    port = 18789;

    # Secrets loaded via environment files (must be in KEY=value format)
    environmentFiles = [
      config.sops.secrets."openclaw/anthropic-oauth-token".path
      config.sops.secrets."openclaw/brave-search-api-key".path
    ];

    config = {
      gateway = {
        bind = "localhost";
        mode = "local";
        # Localhost binding + Telegram channel - no gateway auth needed
      };

      # Telegram channel
      channels.telegram = {
        enabled = true;
        tokenFile = config.sops.secrets."openclaw/telegram-bot-token".path;
        allowFrom = [5875599249];
        groups."*".requireMention = true;
      };

      # Model routing: Haiku default (cheap), Sonnet fallback (complex tasks)
      agents.defaults = {
        model = {
          primary = "anthropic/claude-3-5-haiku-latest";
          fallbacks = ["anthropic/claude-sonnet-4-20250514"];
        };
        workspace = "/var/lib/openclaw/workspace";
        maxConcurrent = 4;
      };

      # Note: contextPruning, compaction, and heartbeat.model are not supported
      # by this OpenClaw version. Token optimization is handled by model routing
      # (Haiku default) and the workspace documents (SOUL.md rules).

      # Web tools
      tools.web = {
        search = {
          enabled = true;
          provider = "brave";
          # API key loaded from BRAVE_SEARCH_API_KEY env var
        };
        fetch.enabled = true;
      };
    };
  };

  # Copy workspace documents to state directory
  systemd.services.openclaw-gateway-workspace = {
    description = "Copy OpenClaw workspace documents";
    before = ["openclaw-gateway.service"];
    requiredBy = ["openclaw-gateway.service"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "copy-workspace" ''
        set -euo pipefail
        mkdir -p /var/lib/openclaw/workspace
        cp -r ${./../../clawdbot-documents}/* /var/lib/openclaw/workspace/
        chown -R openclaw:openclaw /var/lib/openclaw/workspace
      '';
    };
  };

  # --- Networking ---
  # IMPORTANT: Keep public SSH until Tailscale is working with real authkey
  # Once Tailscale is verified working, set openFirewall = false and remove port 22 below
  services.openssh.openFirewall = true;
  services.tailscale = {
    enable = true;
    authKeyFile = config.sops.secrets."tailscale-authkey".path;
    openFirewall = false;
    # Client mode only: do not advertise homelab routes from lildoofy
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
      # Public SSH access (remove once Tailscale is working)
      allowedTCPPorts = [22];
      # SSH + gateway accessible over Tailscale
      interfaces.tailscale0.allowedTCPPorts = [22 18789];
    };
  };

  # --- Disable wait-online services ---
  systemd.services = {
    "NetworkManager-wait-online".enable = lib.mkForce false;
    "systemd-networkd-wait-online".enable = lib.mkForce false;
  };
}
