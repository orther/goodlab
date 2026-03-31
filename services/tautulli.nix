# Tautulli - Plex Media Server Monitor
#
# Monitors Plex usage, viewing history, and statistics.
# Web UI on port 8181.
#
# Post-installation setup:
#   1. Access Tautulli at http://noir:8181
#   2. Connect to Plex server at pie's IP (e.g., 10.0.0.X:32400)
#   3. Sign in with your Plex account
{...}: {
  # ==========================================================================
  # Tautulli Service
  # ==========================================================================

  services.tautulli = {
    enable = true;
    openFirewall = true;
  };

  # ==========================================================================
  # Persistence (for impermanence systems)
  # ==========================================================================

  environment.persistence."/nix/persist" = {
    directories = [
      {
        directory = "/var/lib/tautulli";
        user = "tautulli";
        group = "tautulli";
        mode = "0750";
      }
    ];
  };
}
