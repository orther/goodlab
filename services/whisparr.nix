# Whisparr - Adult Content Management (Radarr fork)
# https://github.com/Whisparr/Whisparr
#
# Whisparr is not packaged in nixpkgs or nixflix, so we run it via OCI container
# using the same Podman pattern as Wizarr.
#
# Container mounts:
#   /config  → /var/lib/whisparr3  (database, config.xml, logs)
#   /data    → /mnt/docker-data    (NAS media via NFS mount)
#   /nzbget  → /var/lib/nzbget     (NZBGet completed downloads on local NVMe)
#
# Path mapping (configured in Whisparr UI → Settings → Download Clients):
#   NZBGet reports paths as /var/lib/nzbget/completed/...
#   Whisparr sees them as   /nzbget/completed/...
#   Remote path mapping:    /var/lib/nzbget/ → /nzbget/
{config, ...}: {
  # ==========================================================================
  # Whisparr OCI Container
  # ==========================================================================

  virtualisation.oci-containers = {
    backend = "podman";
    containers.whisparr3 = {
      image = "ghcr.io/hotio/whisparr:v3";
      ports = ["6969:6969"];
      volumes = [
        "/var/lib/whisparr3:/config:rw"
        "/mnt/docker-data:/data:rw"
        "/var/lib/nzbget:/nzbget:ro"
      ];
      environment = {
        TZ = config.time.timeZone;
        PUID = "0";
        PGID = "0";
        UMASK = "002";
      };
      log-driver = "journald";
    };
  };

  # ==========================================================================
  # Firewall
  # ==========================================================================

  networking.firewall.allowedTCPPorts = [6969];

  # ==========================================================================
  # Systemd Configuration
  # ==========================================================================

  # Ensure config directory exists before container starts
  systemd.tmpfiles.rules = ["d /var/lib/whisparr3 0755 root root"];

  # Wait for NAS mount since Whisparr needs /mnt/docker-data for media
  systemd.services.podman-whisparr3 = {
    after = ["mnt-docker\\x2ddata.mount"];
    requires = ["mnt-docker\\x2ddata.mount"];
  };

  # ==========================================================================
  # Persistence (for impermanence systems)
  # ==========================================================================
  # Whisparr stores its SQLite database, config, and logs in /var/lib/whisparr3.

  environment.persistence."/nix/persist" = {
    directories = [
      "/var/lib/whisparr3"
    ];
  };
}
