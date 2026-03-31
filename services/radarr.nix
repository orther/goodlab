# Radarr - Movie Management
#
# Automated movie downloading and management.
# Web UI on port 7878.
#
# Radarr monitors RSS feeds, searches indexers (via Prowlarr), and sends
# downloads to NZBGet. Completed files are moved to the NAS media library.
#
# Post-migration setup:
#   1. Copy database from pie: /nix/persist/var/lib/nixflix/radarr/ → noir:/nix/persist/var/lib/radarr/
#   2. Verify download client settings point to localhost:6789 (NZBGet)
#   3. Verify indexer connections via Prowlarr (localhost:9696)
{...}: {
  # ==========================================================================
  # Radarr Service
  # ==========================================================================

  services.radarr = {
    enable = true;
    openFirewall = true;
  };

  # Radarr needs nzbget group to read completed downloads from /var/lib/nzbget/
  users.users.radarr.extraGroups = ["nzbget"];

  # Wait for NAS mount — Radarr moves completed downloads to /mnt/media/movies
  systemd.services.radarr = {
    after = ["mnt-docker\\x2ddata.mount"];
    wants = ["mnt-docker\\x2ddata.mount"];
  };

  # ==========================================================================
  # Persistence (for impermanence systems)
  # ==========================================================================

  environment.persistence."/nix/persist" = {
    directories = [
      {
        directory = "/var/lib/radarr";
        user = "radarr";
        group = "radarr";
        mode = "0750";
      }
    ];
  };
}
