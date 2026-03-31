# ==============================================================================
# Cloudflare Tunnel for Noir - Media Management & Automation Server
# ==============================================================================
#
# Locally-managed tunnel with ingress routes defined in Nix config.
# Routes are deployed with `just deploy` — no Cloudflare dashboard needed.
#
# Tunnel ID: 26f62c4f-fdca-4f21-9a92-7f81187df681
# Domain: ryatt.app
#
# To add/remove routes: edit the ingress rules below and redeploy.
# ==============================================================================
{config, ...}: {
  # ==========================================================================
  # SOPS Secret for Tunnel Credentials
  # ==========================================================================

  sops.secrets."cloudflare/tunnel-noir-credentials" = {
    mode = "0444";
  };

  # ==========================================================================
  # Cloudflare Tunnel
  # ==========================================================================

  services.cloudflared = {
    enable = true;
    tunnels."26f62c4f-fdca-4f21-9a92-7f81187df681" = {
      credentialsFile = config.sops.secrets."cloudflare/tunnel-noir-credentials".path;
      default = "http_status:404";

      ingress = {
        # Home automation
        "hass.ryatt.app" = "http://localhost:8123";

        # Media management (*arr stack)
        "sonarr.ryatt.app" = "http://localhost:8989";
        "radarr.ryatt.app" = "http://localhost:7878";
        "prowlarr.ryatt.app" = "http://localhost:9696";
        "nzbget.ryatt.app" = "http://localhost:6789";

        # Media requests & user management
        "seerr.ryatt.app" = "http://localhost:5055";
        "wizarr.ryatt.app" = "http://localhost:5690";

        # Adult content management
        "whisparr.ryatt.app" = "http://localhost:6969";

        # Monitoring
        "tautulli.ryatt.app" = "http://localhost:8181";
        "jellystat.ryatt.app" = "http://localhost:3000";
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
