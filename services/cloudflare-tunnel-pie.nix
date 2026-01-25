# ==============================================================================
# Cloudflare Tunnel for Pie Media Server
# ==============================================================================
#
# Provides secure subdomain-based access to media services via Cloudflare Tunnel.
# This is a zero-trust solution - no ports exposed to the internet.
#
# This uses a REMOTELY-MANAGED tunnel - ingress rules are configured in the
# Cloudflare Zero Trust dashboard, not here. This config just connects.
#
# Subdomains to configure in Cloudflare Dashboard:
#   - jellyfin.ryatt.app → http://localhost:8096
#   - plex.ryatt.app     → http://localhost:32400 [temporary]
#
# Setup requirements:
#   1. Create tunnel in Cloudflare Zero Trust Dashboard
#   2. Copy the tunnel token and save to secrets/cloudflare-tunnel-pie-token
#   3. Configure public hostnames (ingress) in Cloudflare Dashboard
#
# To add more services later, add them in Cloudflare Dashboard:
#   - sonarr.ryatt.app → http://localhost:8989
#   - radarr.ryatt.app → http://localhost:7878
#   - prowlarr.ryatt.app → http://localhost:9696
#   - jellyseerr.ryatt.app → http://localhost:5055
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
  # Save it as a single-line text file and encrypt with SOPS.

  sops.secrets."cloudflare-tunnel-pie-token" = {
    format = "binary";
    sopsFile = ./../secrets/cloudflare-tunnel-pie-token;
  };

  # ==========================================================================
  # Cloudflare Tunnel Service
  # ==========================================================================
  # For remotely-managed tunnels, we just run cloudflared with the token.
  # All ingress configuration is done in Cloudflare's dashboard.

  systemd.services."cloudflared-tunnel-pie" = {
    description = "Cloudflare Tunnel for Pie Media Server";
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
      ExecStart = "${pkgs.cloudflared}/bin/cloudflared tunnel run --token $(cat ${config.sops.secrets."cloudflare-tunnel-pie-token".path})";

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
