# Jellystat - Jellyfin Usage Statistics
#
# Monitors Jellyfin viewing activity, user statistics, and library analytics.
# Web UI on port 3000.
#
# Jellystat requires PostgreSQL. We use NixOS's native services.postgresql
# rather than a container, since it's simpler and more reliable.
#
# Post-installation setup:
#   1. Access Jellystat at http://noir:3000
#   2. Enter Jellyfin server URL (pie's IP, e.g., http://10.0.0.X:8096)
#   3. Enter a Jellyfin API key (generate in Jellyfin → Dashboard → API Keys)
{config, ...}: {
  # ==========================================================================
  # SOPS Secrets
  # ==========================================================================

  sops.secrets."jellystat/postgres-password" = {
    owner = "root";
    mode = "0400";
  };
  sops.secrets."jellystat/jwt-secret" = {
    owner = "root";
    mode = "0400";
  };

  # ==========================================================================
  # PostgreSQL for Jellystat
  # ==========================================================================

  services.postgresql = {
    enable = true;
    ensureDatabases = ["jellystat"];
    ensureUsers = [
      {
        name = "jellystat";
        ensureDBOwnership = true;
      }
    ];
    # Trust local connections for the jellystat user (container connects via host IP)
    authentication = ''
      # Jellystat container connects via TCP to localhost
      host jellystat jellystat 127.0.0.1/32 trust
      host jellystat jellystat ::1/128 trust
    '';
  };

  # ==========================================================================
  # Jellystat OCI Container
  # ==========================================================================

  virtualisation.oci-containers = {
    backend = "podman";
    containers.jellystat = {
      # https://github.com/CyferShepard/Jellystat
      image = "docker.io/cyfershepard/jellystat:latest";
      ports = ["3000:3000"];
      volumes = [
        "/var/lib/jellystat:/app/backend/backup-data:rw"
      ];
      environment = {
        POSTGRES_USER = "jellystat";
        POSTGRES_IP = "127.0.0.1";
        POSTGRES_PORT = "5432";
      };
      # Inject secrets as env vars from SOPS-generated files
      environmentFiles = [
        config.sops.secrets."jellystat/postgres-password".path
        config.sops.secrets."jellystat/jwt-secret".path
      ];
      extraOptions = [
        # Host networking so container can reach PostgreSQL on localhost
        "--network=host"
      ];
      log-driver = "journald";
    };
  };

  # ==========================================================================
  # Firewall
  # ==========================================================================

  networking.firewall.allowedTCPPorts = [3000];

  # ==========================================================================
  # Systemd Configuration
  # ==========================================================================

  systemd.tmpfiles.rules = ["d /var/lib/jellystat 0755 root root"];

  # Start Jellystat after PostgreSQL is ready
  systemd.services.podman-jellystat = {
    after = ["postgresql.service"];
    requires = ["postgresql.service"];
  };

  # ==========================================================================
  # Persistence (for impermanence systems)
  # ==========================================================================

  environment.persistence."/nix/persist" = {
    directories = [
      "/var/lib/jellystat"
      {
        directory = "/var/lib/postgresql";
        user = "postgres";
        group = "postgres";
        mode = "0750";
      }
    ];
  };
}
