# ==============================================================================
# Cloudflare Tunnel for Pie Media Server
# ==============================================================================
#
# Provides secure subdomain-based access to media services via Cloudflare Tunnel.
# This is a zero-trust solution - no ports exposed to the internet.
#
# Subdomains configured:
#   - jellyfin.ryatt.app → Jellyfin (port 8096)
#   - plex.ryatt.app     → Plex (port 32400) [temporary, remove with plex.nix]
#
# Setup requirements:
#   1. Create tunnel in Cloudflare Zero Trust Dashboard
#   2. Download credentials JSON and encrypt with SOPS
#   3. Ensure ryatt.app is added to your Cloudflare account
#
# To add more services later (e.g., *arr stack):
#   "sonarr.ryatt.app".service = "http://localhost:8989";
#   "radarr.ryatt.app".service = "http://localhost:7878";
#   "prowlarr.ryatt.app".service = "http://localhost:9696";
#   "jellyseerr.ryatt.app".service = "http://localhost:5055";
# ==============================================================================
{
  config,
  pkgs,
  lib,
  ...
}: {
  # ==========================================================================
  # SOPS Secrets for Tunnel Credentials
  # ==========================================================================
  # The tunnel credentials file is a JSON file downloaded from Cloudflare
  # when creating the tunnel. It contains the tunnel ID and secret.

  sops.secrets."cloudflare-tunnel-pie" = {
    owner = config.services.cloudflared.user;
    inherit (config.services.cloudflared) group;
    format = "binary";
    sopsFile = ./../secrets/cloudflare-tunnel-pie;
  };

  # ==========================================================================
  # Cloudflare Tunnel Configuration
  # ==========================================================================

  services.cloudflared = {
    enable = true;

    tunnels."pie-media" = {
      # Credentials file from SOPS
      credentialsFile = config.sops.secrets."cloudflare-tunnel-pie".path;

      # Default response for unmatched requests
      default = "http_status:404";

      # Ingress rules - map subdomains to local services
      ingress = {
        # ======================================================================
        # Jellyfin - Primary Media Server
        # ======================================================================
        # Free, open-source, no ads, free hardware transcoding
        "jellyfin.ryatt.app" = {
          service = "http://localhost:8096";
        };

        # ======================================================================
        # Plex - TEMPORARY (remove when plex.nix is removed)
        # ======================================================================
        # Kept for family migration period
        "plex.ryatt.app" = {
          service = "http://localhost:32400";
        };

        # ======================================================================
        # Future: *arr Services (uncomment when enabled in nixflix)
        # ======================================================================
        # "sonarr.ryatt.app" = {
        #   service = "http://localhost:8989";
        # };
        # "radarr.ryatt.app" = {
        #   service = "http://localhost:7878";
        # };
        # "prowlarr.ryatt.app" = {
        #   service = "http://localhost:9696";
        # };
        # "jellyseerr.ryatt.app" = {
        #   service = "http://localhost:5055";
        # };
      };
    };
  };

  # ==========================================================================
  # DNS Route Configuration
  # ==========================================================================
  # Automatically creates CNAME records in Cloudflare DNS pointing
  # subdomains to the tunnel. Only runs once per subdomain.

  systemd.services."cloudflared-dns-routes-pie" = {
    description = "Configure DNS routes for pie media tunnel";
    after = ["cloudflared-tunnel-pie-media.service" "network-online.target"];
    wants = ["cloudflared-tunnel-pie-media.service"];
    wantedBy = ["multi-user.target"];

    # Use the same environment as cloudflared for authentication
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = config.services.cloudflared.user;
      Group = config.services.cloudflared.group;

      ExecStart = pkgs.writeShellScript "setup-pie-dns-routes" ''
        set -euo pipefail

        # Wait for tunnel to be ready
        sleep 5

        echo "Configuring DNS routes for pie-media tunnel..."

        # Create DNS records (idempotent - Cloudflare handles duplicates)
        ${lib.getExe pkgs.cloudflared} tunnel route dns 'pie-media' 'jellyfin.ryatt.app' || true
        ${lib.getExe pkgs.cloudflared} tunnel route dns 'pie-media' 'plex.ryatt.app' || true

        echo "DNS routes configured successfully"
      '';
    };
  };

  # ==========================================================================
  # Persistence (for impermanence systems)
  # ==========================================================================
  # Cloudflared stores connection state and metrics

  environment.persistence."/nix/persist" = {
    directories = [
      {
        directory = "/var/lib/cloudflared";
        user = config.services.cloudflared.user;
        group = config.services.cloudflared.group;
        mode = "0700";
      }
    ];
  };
}
