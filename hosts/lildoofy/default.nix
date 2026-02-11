# lildoofy - Hetzner Cloud VPS for OpenClaw (Lil Doofy bot)
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
    inputs.nix-openclaw.nixosModules.openclaw

    ./hardware-configuration.nix

    inputs.self.nixosModules.base
    inputs.self.nixosModules."auto-update"

    ./../../services/openclaw.nix
    ./../../services/ollama.nix
  ];

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

  # --- OpenClaw Service ---
  services.openclaw = {
    enable = true;
    workspaceDir = ./../../clawdbot-documents;

    instances.default = {
      enable = true;

      providers.telegram = {
        enable = true;
        botTokenFile = config.sops.secrets."openclaw/telegram-bot-token".path;
        allowFrom = [5875599249];
        groups = {
          "*" = {requireMention = true;};
        };
      };

      providers.anthropic = {
        oauthTokenFile = config.sops.secrets."openclaw/anthropic-oauth-token".path;
      };

      gateway.auth = {
        mode = "token";
        tokenFile = config.sops.secrets."openclaw/gateway-token".path;
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
  systemd.services.openclaw-brave-env = {
    description = "Inject Brave Search API key into OpenClaw config";
    before = ["openclaw-gateway.service"];
    requiredBy = ["openclaw-gateway.service"];
    after = ["sops-nix.service"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "inject-brave-key" ''
        set -euo pipefail
        key_file="${config.sops.secrets."openclaw/brave-search-api-key".path}"
        config_file="/var/lib/openclaw/openclaw.json"

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
