# ==============================================================================
# Cloudflare Tunnel for Zinc (Condo)
# ==============================================================================
#
# Provides secure subdomain-based access to services via Cloudflare Tunnel.
# This is a zero-trust solution - no ports exposed to the internet.
#
# This uses a REMOTELY-MANAGED tunnel - ingress rules are configured in the
# Cloudflare Zero Trust dashboard, not here. This config just connects.
#
# Subdomains to configure in Cloudflare Dashboard:
#   - condo.ryatt.app  -> http://localhost:8123
#   - unifi.ryatt.app  -> https://localhost:8443  (enable "No TLS Verify" in dashboard)
#
# Setup requirements:
#   1. Create tunnel in Cloudflare Zero Trust Dashboard
#   2. Add tunnel token to secrets/secrets.yaml as "cloudflare-tunnel-zinc-token"
#   3. Configure public hostnames (ingress) in Cloudflare Dashboard
#
# ==============================================================================
{
  config,
  pkgs,
  ...
}: {
  # ==========================================================================
  # Static system user for cloudflared
  # ==========================================================================
  # A static user (not DynamicUser) ensures stable UID ownership on the
  # persisted /var/lib/cloudflared directory across reboots.

  users.users.cloudflared = {
    isSystemUser = true;
    group = "cloudflared";
  };
  users.groups.cloudflared = {};

  # ==========================================================================
  # SOPS Secret for Tunnel Token
  # ==========================================================================
  # mode 0400 + explicit owner so only the cloudflared service user can read
  # the token. A Cloudflare tunnel token grants full tunnel control.

  sops.secrets."cloudflare-tunnel-zinc-token" = {
    mode = "0400";
    owner = "cloudflared";
    group = "cloudflared";
  };

  # ==========================================================================
  # Cloudflare Tunnel Service
  # ==========================================================================

  systemd.services."cloudflared-tunnel-zinc" = {
    description = "Cloudflare Tunnel for Zinc Condo Server";
    after = ["network-online.target"];
    wants = ["network-online.target"];
    wantedBy = ["multi-user.target"];

    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = "5s";

      User = "cloudflared";
      Group = "cloudflared";

      ExecStart = pkgs.writeShellScript "cloudflared-tunnel-zinc" ''
        exec ${pkgs.cloudflared}/bin/cloudflared tunnel run --token "$(cat ${config.sops.secrets."cloudflare-tunnel-zinc-token".path})"
      '';

      # Security hardening
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
    };
  };

  # ==========================================================================
  # Persistence (for impermanence systems)
  # ==========================================================================
  # Static user ensures ownership is stable across reboots.

  environment.persistence."/nix/persist" = {
    directories = [
      {
        directory = "/var/lib/cloudflared";
        user = "cloudflared";
        group = "cloudflared";
        mode = "0750";
      }
    ];
  };
}
