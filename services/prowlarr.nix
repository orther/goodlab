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
{lib, ...}: {
  # ==========================================================================
  # Prowlarr Service
  # ==========================================================================
  # The NixOS prowlarr module uses DynamicUser=true which conflicts with
  # impermanence bind mounts (/var/lib/private must be 0700, but impermanence
  # creates it at 0755). Override to use a static user like sonarr/radarr.

  services.prowlarr = {
    enable = true;
    openFirewall = true;
  };

  # Override DynamicUser to avoid /var/lib/private permission conflict
  systemd.services.prowlarr.serviceConfig = {
    DynamicUser = lib.mkForce false;
    User = "prowlarr";
    Group = "prowlarr";
  };

  users.users.prowlarr = {
    isSystemUser = true;
    group = "prowlarr";
    home = "/var/lib/prowlarr";
  };
  users.groups.prowlarr = {};

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
