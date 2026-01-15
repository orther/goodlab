# Plex Media Server configuration with Intel Quick Sync hardware transcoding
#
# Key features:
# - Hardware transcoding via Intel Quick Sync Video (QSV)
# - Media accessed via NAS mount (services/nas.nix)
# - Automatic firewall configuration
# - Persistence for impermanence systems
#
# Post-installation setup:
# 1. Access Plex at http://<ip>:32400/web (or via SSH tunnel for remote setup)
# 2. Sign in with Plex account to claim the server
# 3. Enable hardware transcoding in Settings → Transcoder → "Use hardware acceleration when available"
# 4. Add media libraries:
#    - Movies: /mnt/media/movies
#    - TV:     /mnt/media/tv
{pkgs, ...}: {
  # ==========================================================================
  # NAS Media Location
  # ==========================================================================
  # Media files are accessed via the NAS mount from services/nas.nix
  # which mounts /volume1/docker-data to /mnt/docker-data
  #
  # A symlink provides a cleaner path for Plex:
  #   /mnt/media -> /mnt/docker-data/media
  #
  # When adding Plex libraries, use:
  #   /mnt/media/movies
  #   /mnt/media/tv

  # Create symlink: /mnt/media -> /mnt/docker-data/media
  systemd.tmpfiles.rules = [
    "L+ /mnt/media - - - - /mnt/docker-data/media"
  ];

  # ==========================================================================
  # Plex Media Server
  # ==========================================================================

  services.plex = {
    enable = true;

    # Open firewall for Plex ports:
    # - 32400: Main Plex web interface and streaming
    # - 32469: Plex DLNA server
    # - 1900/udp: DLNA discovery
    # - 32410-32414/udp: GDM network discovery
    openFirewall = true;

    # Critical: Pass GPU render device for Quick Sync hardware transcoding
    # This gives Plex access to the Intel GPU at /dev/dri/renderD128
    accelerationDevices = ["/dev/dri/renderD128"];
  };

  # ==========================================================================
  # Additional Plex Packages
  # ==========================================================================
  # Optional: Install Plex companion tools

  environment.systemPackages = with pkgs; [
    # VA-API utilities for debugging hardware acceleration
    libva-utils # Provides 'vainfo' to check VA-API status

    # Intel GPU monitoring tools
    intel-gpu-tools # Provides 'intel_gpu_top' for monitoring GPU usage
  ];

  # ==========================================================================
  # Persistence (for impermanence systems)
  # ==========================================================================
  # Plex stores its database, metadata, and cache in /var/lib/plex
  # This must be persisted across reboots to keep library and watch history

  environment.persistence."/nix/persist" = {
    directories = [
      {
        directory = "/var/lib/plex";
        user = "plex";
        group = "plex";
        mode = "0700";
      }
    ];
  };

  # ==========================================================================
  # Systemd Service Adjustments
  # ==========================================================================
  # Ensure Plex waits for network and NAS mount before starting
  # Note: hyphen in path becomes \x2d in systemd unit names

  systemd.services.plex = {
    after = ["network-online.target" "mnt-docker\\x2ddata.mount"];
    wants = ["network-online.target"];
    requires = ["mnt-docker\\x2ddata.mount"];
  };
}
