# ==============================================================================
# TEMPORARY: Plex Media Server - Migration Service Only
# ==============================================================================
#
# !! THIS SERVICE IS TEMPORARY !!
#
# Plex is being phased out in favor of Jellyfin due to:
# - Monetization frustrations (rental/purchase ads in the UI)
# - Paid hardware transcoding (Plex Pass required)
# - Increasing feature restrictions for non-paying users
#
# Jellyfin provides:
# - Completely free and open source
# - Free hardware transcoding (no subscription needed)
# - No ads or upsells in the interface
# - Full control over your media server
#
# MIGRATION TIMELINE: 2-4 weeks
# =============================
# This service exists only to give family members time to transition
# from Plex clients to Jellyfin clients. Once migration is complete:
#
# 1. Remove this import from hosts/pie/default.nix
# 2. Remove users.users.plex.extraGroups line from hosts/pie/default.nix
# 3. Rebuild: just deploy pie <ip>
#
# Post-installation setup (if needed):
# 1. Access Plex at http://pie:32400/web (or via SSH tunnel)
# 2. Sign in with Plex account to claim the server
# 3. Enable hardware transcoding in Settings → Transcoder
# 4. Add media libraries: /mnt/media/movies, /mnt/media/tv
# ==============================================================================
{pkgs, ...}: {
  # ==========================================================================
  # Plex Media Server (TEMPORARY)
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
  # Debugging tools for hardware acceleration

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
