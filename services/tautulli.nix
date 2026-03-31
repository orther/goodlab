# Tautulli - Plex Media Server Monitor
#
# Monitors Plex usage, viewing history, and statistics.
# Web UI on port 8181.
#
# Note: The NixOS tautulli module uses the legacy "plexpy" path and user
# (from when Tautulli was called PlexPy). Data lives in /var/lib/plexpy.
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
  # NixOS module stores data in /var/lib/plexpy (legacy PlexPy path),
  # running as user plexpy.

  environment.persistence."/nix/persist" = {
    directories = [
      "/var/lib/plexpy"
    ];
  };
}
