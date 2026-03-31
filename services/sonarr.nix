# Sonarr - TV Series Management
#
# Automated TV series downloading and management.
# Web UI on port 8989.
#
# Sonarr monitors RSS feeds, searches indexers (via Prowlarr), and sends
# downloads to NZBGet. Completed files are moved to the NAS media library.
#
# Post-migration setup:
#   1. Copy database from pie: /nix/persist/var/lib/nixflix/sonarr/ → noir:/nix/persist/var/lib/sonarr/
#   2. Verify download client settings point to localhost:6789 (NZBGet)
#   3. Verify indexer connections via Prowlarr (localhost:9696)
{...}: {
  # ==========================================================================
  # Sonarr Service
  # ==========================================================================

  services.sonarr = {
    enable = true;
    openFirewall = true;
  };

  # Sonarr needs nzbget group to read completed downloads from /var/lib/nzbget/
  users.users.sonarr.extraGroups = ["nzbget"];

  # Wait for NAS mount — Sonarr moves completed downloads to /mnt/media/tv
  systemd.services.sonarr = {
    after = ["mnt-docker\\x2ddata.mount"];
    wants = ["mnt-docker\\x2ddata.mount"];
  };

  # ==========================================================================
  # Persistence (for impermanence systems)
  # ==========================================================================

  environment.persistence."/nix/persist" = {
    directories = [
      {
        directory = "/var/lib/sonarr";
        user = "sonarr";
        group = "sonarr";
        mode = "0750";
      }
    ];
  };
}
