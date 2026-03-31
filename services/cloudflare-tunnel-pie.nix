# ==============================================================================
# Cloudflare Tunnel for Pie - Media Playback Server
# ==============================================================================
#
# Locally-managed tunnel with ingress routes defined in Nix config.
# Routes are deployed with `just deploy` — no Cloudflare dashboard needed.
#
# Tunnel ID: 850330bb-5ed9-4599-9716-e3ba8ec3fce8
# Domain: ryatt.app
#
# To add/remove routes: edit the ingress rules below and redeploy.
# ==============================================================================
{config, ...}: {
  # ==========================================================================
  # SOPS Secret for Tunnel Credentials
  # ==========================================================================

  sops.secrets."cloudflare/tunnel-pie-credentials" = {
    mode = "0444";
  };

  # ==========================================================================
  # Cloudflare Tunnel
  # ==========================================================================

  services.cloudflared = {
    enable = true;
    tunnels."850330bb-5ed9-4599-9716-e3ba8ec3fce8" = {
      credentialsFile = config.sops.secrets."cloudflare/tunnel-pie-credentials".path;
      default = "http_status:404";

      ingress = {
        "jellyfin.ryatt.app" = "http://localhost:8096";
        "plex.ryatt.app" = "http://localhost:32400";
      };
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
