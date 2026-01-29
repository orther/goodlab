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
    #inputs.nixarr.nixosModules.default
    inputs.nix-clawdbot.nixosModules.clawdbot

    ./hardware-configuration.nix

    inputs.self.nixosModules.base
    inputs.self.nixosModules."remote-unlock"
    inputs.self.nixosModules."auto-update"

    ./../../services/nas.nix
    ./../../services/tailscale.nix
    ./../../services/_acme.nix
    ./../../services/_nginx.nix
    #./../../services/netdata.nix
    #./../../services/nextcloud.nix
    #./../../services/nixarr.nix

    # Research Relay services disabled - spamming errors
    # ./../../services/research-relay/_common-hardening.nix
    # ./../../services/research-relay/odoo.nix
    # ./../../services/research-relay/pdf-intake.nix
    # ./../../services/research-relay/age-gate.nix
    # ./../../services/research-relay/secrets.nix
  ];

  home-manager = {
    extraSpecialArgs = {inherit inputs outputs;};
    useGlobalPkgs = true;
    useUserPackages = true;
    users = {
      orther = {
        config,
        pkgs,
        lib,
        ...
      }: {
        imports = [
          inputs.self.lib.hmModules.base
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

        programs.ssh = {
          enable = true;
          enableDefaultConfig = false;
          matchBlocks = {
            "github.com" = {
              hostname = "github.com";
              identityFile = "~/.ssh/id_ed25519";
            };
            # Add more hosts as needed
          };
        };

      };
    };
  };

  # System-level SOPS secrets for the hardened Clawdbot service
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

  # Clawdbot - hardened system service (PR #24)
  services.clawdbot = {
    enable = true;
    documents = ./../../clawdbot-documents;

    instances.default = {
      enable = true;

      providers.telegram = {
        enable = true;
        botTokenFile = config.sops.secrets."clawdbot/telegram-bot-token".path;
        allowFrom = [5875599249]; # Your Telegram user ID from @userinfobot
        groups = {
          "*" = {requireMention = true;}; # Required in Nix mode
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
        # Bind gateway to Tailscale only for resilient private access.
        gateway.bind = "tailnet";

        # Web search via Brave Search API (key injected at runtime via env)
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

  networking = {
    hostName = "noir";
    useDHCP = false;
    interfaces.enp2s0.useDHCP = true;
    useNetworkd = true;
    networkmanager.enable = lib.mkForce false; # Override base.nix NetworkManager setting
    firewall.allowedTCPPorts = [];
    firewall.interfaces.tailscale0.allowedTCPPorts = [18789];

    # Local DNS resolution for Odoo subdomain
    # Tailscale MagicDNS will handle this for Tailscale clients
    # For local network clients without Tailscale, add noir's local IP to their /etc/hosts:
    #   10.0.10.X odoo.orther.dev
    hosts = {
      "127.0.0.1" = ["odoo.orther.dev"];
    };
  };

  # Inject Brave Search API key into the gateway config JSON at runtime.
  # The config is in the writable state dir; we patch it before the gateway reads it.
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
          # Remove any existing apiKey first (idempotent), then inject fresh
          ${pkgs.gnused}/bin/sed -i \
            -e 's|,"apiKey":"[^"]*"||g' \
            -e "s|\"provider\":\"brave\"|\"provider\":\"brave\",\"apiKey\":\"$api_key\"|" \
            "$config_file"
        fi
      '';
    };
  };

  # Disable problematic wait services during NetworkManager -> systemd-networkd transition
  systemd.services = {
    "NetworkManager-wait-online".enable = lib.mkForce false;
    "systemd-networkd-wait-online".enable = lib.mkForce false;
  };

  # Research Relay services disabled - spamming errors and not in use
  # services.researchRelay = {
  #   odoo.enable = false;
  #   pdfIntake.enable = false;
  # };
}
