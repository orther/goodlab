# Jellyseerr - Media Request Manager
#
# User-facing request interface for Jellyfin and Plex media servers.
# Web UI on port 5055.
#
# Jellyseerr is not in nixpkgs, so we run it via OCI container.
#
# Post-migration setup:
#   1. Copy database from pie: /nix/persist/var/lib/nixflix/jellyseerr/ → noir:/nix/persist/var/lib/jellyseerr/
#   2. Update Jellyfin/Plex server URLs in Settings to point to pie's IP
#   3. Update Sonarr/Radarr connections to point to localhost
{config, ...}: {
  # ==========================================================================
  # Jellyseerr OCI Container
  # ==========================================================================

  virtualisation.oci-containers = {
    backend = "podman";
    containers.jellyseerr = {
      # https://github.com/Fallenbagel/jellyseerr
      image = "docker.io/fallenbagel/jellyseerr:latest";
      ports = ["5055:5055"];
      volumes = [
        "/var/lib/jellyseerr:/app/config:rw"
      ];
      environment = {
        TZ = config.time.timeZone;
        LOG_LEVEL = "info";
      };
      log-driver = "journald";
    };
  };

  # ==========================================================================
  # Firewall
  # ==========================================================================

  networking.firewall.allowedTCPPorts = [5055];

  # ==========================================================================
  # Systemd Configuration
  # ==========================================================================

  systemd.tmpfiles.rules = ["d /var/lib/jellyseerr 0755 root root"];

  # ==========================================================================
  # Persistence (for impermanence systems)
  # ==========================================================================

  environment.persistence."/nix/persist" = {
    directories = [
      "/var/lib/jellyseerr"
    ];
  };
}
