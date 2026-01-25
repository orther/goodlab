{...}: {
  services.rpcbind.enable = true;

  # ==========================================================================
  # NFS Mount - Synology NAS
  # ==========================================================================
  # Mounts media storage from Synology NAS at 10.4.0.50 (local network).
  #
  # SECURITY NOTE: This NFS mount relies on local network trust. The NAS is
  # on a trusted home network segment. For production environments, consider:
  # - NFSv4 with Kerberos authentication
  # - VPN-only access (Tailscale provides this for remote access)
  # - Firewall rules limiting NFS to specific hosts
  #
  # For this home media server, local network trust is acceptable since:
  # - NAS and server are on the same physical network
  # - Remote access is via Tailscale (encrypted tunnel)
  # - Media files are not sensitive data

  fileSystems."/mnt/docker-data" = {
    device = "10.4.0.50:/volume1/docker-data";
    fsType = "nfs";
    options = [
      # Protocol version
      "nfsvers=4.1"
      "tcp" # Explicit TCP for reliability

      # Performance tuning for media streaming (large sequential reads)
      "rsize=1048576" # 1MB read buffer - optimal for large media files
      "wsize=1048576" # 1MB write buffer - for downloads/transcoding cache
      "noatime" # Don't update access times (reduces write overhead)
      "actimeo=3" # Attribute cache timeout (balance freshness vs performance)

      # Reliability options
      "hard" # Retry indefinitely on network issues (prevents data corruption)
      "intr" # Allow interrupt of hung operations
      "timeo=150" # 15 second timeout before retry
      "retrans=3" # Retry 3 times before reporting error
    ];
  };
}
