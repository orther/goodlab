# ==============================================================================
# Cloudflare Tunnel for Noir Homelab Server
# ==============================================================================
#
# Provides secure subdomain-based access to services via Cloudflare Tunnel.
# This is a zero-trust solution - no ports exposed to the internet.
#
# This uses a REMOTELY-MANAGED tunnel - ingress rules are configured in the
# Cloudflare Zero Trust dashboard, not here. This config just connects.
#
# Subdomains to configure in Cloudflare Dashboard:
#   - hass.ryatt.app → http://localhost:8123
#
# Setup requirements:
#   1. Create tunnel in Cloudflare Zero Trust Dashboard
#   2. Add tunnel token to secrets/secrets.yaml as "cloudflare-tunnel-noir-token"
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
  # The tunnel token is the long string from "cloudflared service install <token>"
  # Add to secrets/secrets.yaml: cloudflare-tunnel-noir-token: "<token>"

  sops.secrets."cloudflare-tunnel-noir-token" = {
    # Mode 0444 allows the DynamicUser to read the token
    # Token is still encrypted at rest, only decrypted to tmpfs at runtime
    mode = "0444";
  };

  # ==========================================================================
  # Cloudflare Tunnel Service
  # ==========================================================================
  # For remotely-managed tunnels, we just run cloudflared with the token.
  # All ingress configuration is done in Cloudflare's dashboard.

  systemd.services."cloudflared-tunnel-noir" = {
    description = "Cloudflare Tunnel for Noir Homelab Server";
    after = ["network-online.target"];
    wants = ["network-online.target"];
    wantedBy = ["multi-user.target"];

    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = "5s";

      # Run as dedicated user for security
      DynamicUser = true;
      User = "cloudflared";

      # Read token from SOPS secret and run tunnel
      ExecStart = pkgs.writeShellScript "cloudflared-tunnel-noir" ''
        exec ${pkgs.cloudflared}/bin/cloudflared tunnel run --token "$(cat ${config.sops.secrets."cloudflare-tunnel-noir-token".path})"
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
  # Cloudflared may store some state, but for token-based tunnels it's minimal

  environment.persistence."/nix/persist" = {
    directories = [
      "/var/lib/cloudflared"
    ];
  };
}
