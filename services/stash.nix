# ==============================================================================
# Stash - Adult Media Organizer
# ==============================================================================
# Native NixOS service using pkgs.stash.
#
# Media library: /mnt/docker-data/media/pr0n (Synology NAS via NFS)
# Access: http://localhost:9999 (local) / Cloudflare Tunnel (remote)
#
# Credentials stored in secrets/secrets.yaml (SOPS):
#   - stash-jwt-secret: JWT signing key
#   - stash-session-key: Session store key
#   - stash-password: Admin password (username: admin)
#
# ==============================================================================
{config, ...}: {
  # ==========================================================================
  # SOPS Secrets
  # ==========================================================================
  sops.secrets = {
    "stash-jwt-secret" = {
      owner = "stash";
      mode = "0400";
    };
    "stash-session-key" = {
      owner = "stash";
      mode = "0400";
    };
    "stash-password" = {
      owner = "stash";
      mode = "0400";
    };
  };

  # ==========================================================================
  # Stash Service
  # ==========================================================================
  services.stash = {
    enable = true;
    openFirewall = true;

    jwtSecretKeyFile = config.sops.secrets."stash-jwt-secret".path;
    sessionStoreKeyFile = config.sops.secrets."stash-session-key".path;

    username = "admin";
    passwordFile = config.sops.secrets."stash-password".path;

    # Allow config and plugin changes made in the UI to persist across restarts
    mutableSettings = true;
    mutablePlugins = true;
    mutableScrapers = true;

    settings = {
      host = "0.0.0.0";
      stash = [
        {
          path = "/mnt/docker-data/media/pr0n";
        }
      ];
    };
  };

  # Wait for the NAS mount before starting — unit name is systemd-escaped
  # /mnt/docker-data → mnt-docker\x2ddata.mount
  systemd.services.stash = {
    after = ["mnt-docker\\x2ddata.mount"];
    wants = ["mnt-docker\\x2ddata.mount"];
  };

  # ==========================================================================
  # Persistence (Impermanence)
  # ==========================================================================
  # Stash database, generated thumbnails/previews, plugins, and scrapers must
  # survive reboots. Media files live on the NAS and are already persistent.

  environment.persistence."/nix/persist" = {
    directories = [
      {
        directory = "/var/lib/stash";
        user = "stash";
        group = "stash";
        mode = "0750";
      }
    ];
  };
}
