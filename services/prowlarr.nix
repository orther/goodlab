# Prowlarr - Indexer Manager
#
# Centralized indexer/tracker management for Sonarr, Radarr, and Whisparr.
# Web UI on port 9696.
#
# Prowlarr manages indexer configurations in one place and syncs them
# to all connected *arr applications.
#
# Post-migration setup:
#   1. Copy database from pie: /nix/persist/var/lib/nixflix/prowlarr/ → noir:/nix/persist/var/lib/prowlarr/
#   2. Verify app connections point to localhost for Sonarr/Radarr
{...}: {
  # ==========================================================================
  # Prowlarr Service
  # ==========================================================================

  services.prowlarr = {
    enable = true;
    openFirewall = true;
  };

  # ==========================================================================
  # Persistence (for impermanence systems)
  # ==========================================================================

  environment.persistence."/nix/persist" = {
    directories = [
      {
        directory = "/var/lib/prowlarr";
        user = "prowlarr";
        group = "prowlarr";
        mode = "0750";
      }
    ];
  };
}
