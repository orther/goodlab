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
#   - condo.ryatt.app -> http://localhost:8123
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
  # SOPS Secret for Tunnel Token
  # ==========================================================================

  sops.secrets."cloudflare-tunnel-zinc-token" = {
    mode = "0444";
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

      DynamicUser = true;
      User = "cloudflared";

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

  environment.persistence."/nix/persist" = {
    directories = [
      "/var/lib/cloudflared"
    ];
  };
}
