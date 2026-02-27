# Wizarr - Media server user invitation management
# https://github.com/wizarrrr/wizarr
#
# Wizarr provides automatic user invitation and management for media servers
# (Jellyfin, Plex). It has no native NixOS package, so we run it via OCI container.
#
# Post-installation setup:
#   1. Access Wizarr at http://pie:5690
#   2. Complete the setup wizard (select Jellyfin, enter server URL)
#   3. Create invitation links to share with family/friends
{...}: {
  # ==========================================================================
  # Podman Container Runtime
  # ==========================================================================

  virtualisation.podman = {
    enable = true;
    autoPrune.enable = true;
    dockerCompat = true;
    defaultNetwork.settings = {
      # Required for container networking to be able to use names.
      dns_enabled = true;
    };
  };

  # ==========================================================================
  # Wizarr OCI Container
  # ==========================================================================

  virtualisation.oci-containers = {
    backend = "podman";
    containers.wizarr = {
      image = "ghcr.io/wizarrrr/wizarr:latest";
      ports = ["5690:5690"];
      volumes = [
        "/var/lib/wizarr:/data:rw"
      ];
      environment = {
        TZ = "America/Los_Angeles";
      };
      labels = {
        "io.containers.autoupdate" = "registry";
      };
      log-driver = "journald";
      extraOptions = [
        "--log-opt=max-file=10"
        "--log-opt=max-size=10m"
      ];
    };
  };

  # ==========================================================================
  # Firewall
  # ==========================================================================

  networking.firewall.allowedTCPPorts = [5690];

  # ==========================================================================
  # Systemd Configuration
  # ==========================================================================

  systemd.tmpfiles.rules = ["d /var/lib/wizarr 0755 root root"];

  # ==========================================================================
  # Persistence (for impermanence systems)
  # ==========================================================================
  # Wizarr stores its SQLite database and configuration in /var/lib/wizarr.
  # /var/lib/containers stores podman images and layers.

  environment.persistence."/nix/persist" = {
    directories = [
      "/var/lib/wizarr"
      "/var/lib/containers"
    ];
  };
}
