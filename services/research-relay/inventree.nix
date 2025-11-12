# InvenTree inventory management service using nixos-inventree module
# Native NixOS service (no Docker) with proper systemd integration
{
  config,
  pkgs,
  lib,
  ...
}: let
  inventreeDomain = "inventree.orther.dev";
  inventreePort = 8000;
in {
  config = lib.mkIf config.services.researchRelay.inventree.enable {
    # PostgreSQL database for InvenTree
    services.postgresql = {
      enable = true;
      package = pkgs.postgresql_16;
      ensureDatabases = ["inventree"];
      ensureUsers = [
        {
          name = "inventree";
          ensureDBOwnership = true;
        }
      ];
      # InvenTree connects via localhost, no need for network access
      settings = {
        listen_addresses = lib.mkDefault "localhost";
      };
      authentication = ''
        # Allow inventree user from localhost
        host inventree inventree 127.0.0.1/32 scram-sha-256
        # Allow local peer authentication
        local inventree inventree peer map=inventree
        local all postgres peer
      '';
      identMap = ''
        inventree inventree inventree
        inventree root postgres
      '';
      # Initialize inventree user password
      initialScript = pkgs.writeText "init-inventree-db.sql" ''
        ALTER USER inventree WITH PASSWORD 'inventree';
      '';
    };

    # Redis cache for InvenTree
    services.redis.servers.inventree = {
      enable = true;
      port = 6379;
      bind = "127.0.0.1"; # Localhost only
      requirePass = "inventree";
      settings = {
        maxmemory = "256mb";
        maxmemory-policy = "allkeys-lru";
      };
    };

    # InvenTree service configuration
    services.inventree = {
      enable = true;

      # Network configuration - bind to localhost for nginx reverse proxy
      bindIp = "127.0.0.1";
      bindPort = inventreePort;

      # Public URL - critical for CSRF, redirects, email links
      siteUrl = "https://${inventreeDomain}";

      # Django ALLOWED_HOSTS security
      allowedHosts = [inventreeDomain];

      # Allow time for database migrations on startup
      serverStartTimeout = "10min";

      # InvenTree configuration (passed to config.yaml)
      config = {
        # PostgreSQL database
        database = {
          ENGINE = "django.db.backends.postgresql";
          NAME = "inventree";
          USER = "inventree";
          PASSWORD = "inventree";
          HOST = "127.0.0.1";
          PORT = 5432;
        };

        # Redis cache
        cache = {
          host = "127.0.0.1";
          port = 6379;
          password = "inventree";
        };

        # Storage paths (managed by systemd)
        static_root = "/var/lib/inventree/static";
        media_root = "/var/lib/inventree/media";
        backup_dir = "/var/backups/inventree";

        # Application settings
        debug = false;
        log_level = "WARNING";
        plugins_enabled = true;

        # Security
        secret_key_file = "/var/lib/inventree/secret_key.txt";

        # Email configuration (Migadu SMTP)
        # Note: Basic config here, sensitive values via environment variables below
        # Using port 587 with STARTTLS instead of 465 with SSL due to Django SMTP issues
        # Using custom backend that doesn't persist connections (fixes Django-Q worker issues)
        email = {
          backend = "inventree_email_backend.EmailBackend";
          host = "smtp.migadu.com";
          port = 587;
          tls = true; # Port 587 uses STARTTLS
          ssl = false;
        };
      };

      # Declarative admin user (uses SOPS secrets)
      users = {
        orther = {
          email = "brandon@orther.dev";
          is_superuser = true;
          password_file = config.sops.secrets."research-relay/inventree/admin-password".path;
        };
      };
    };

    # Systemd service overrides for InvenTree email configuration
    # Note: InvenTree does NOT support *_FILE for email vars, only for ADMIN_PASSWORD and SECRET_KEY
    # We need to read the files and set the values directly as environment variables
    # Both server and cluster need access to email credentials
    systemd.services.inventree-server.serviceConfig.EnvironmentFile = [
      config.sops.templates."inventree-email-env".path
    ];
    systemd.services.inventree-cluster.serviceConfig.EnvironmentFile = [
      config.sops.templates."inventree-email-env".path
    ];

    # Django EMAIL_TIMEOUT to prevent connection reuse issues
    systemd.services.inventree-server.environment.EMAIL_TIMEOUT = "30";

    # Add custom email backend to Python path (both server and cluster need it)
    systemd.services.inventree-server.environment.PYTHONPATH = "/var/lib/inventree";
    systemd.services.inventree-cluster.environment.PYTHONPATH = "/var/lib/inventree";

    # SOPS template to create environment file with email credentials
    sops.templates."inventree-email-env" = {
      content = ''
        INVENTREE_EMAIL_USERNAME=${config.sops.placeholder."research-relay/inventree/smtp-user"}
        INVENTREE_EMAIL_PASSWORD=${config.sops.placeholder."research-relay/inventree/smtp-password"}
        INVENTREE_EMAIL_SENDER=${config.sops.placeholder."research-relay/inventree/smtp-user"}
      '';
      owner = "inventree";
      mode = "0400";
    };

    # Use wildcard certificate from _acme.nix (*.orther.dev)
    # The wildcard cert covers inventree.orther.dev and is managed centrally

    # Nginx reverse proxy for Tailscale access
    services.nginx.virtualHosts."${inventreeDomain}" = {
      forceSSL = true;
      useACMEHost = "orther.dev"; # Use wildcard cert

      extraConfig = ''
        # Security headers
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header Referrer-Policy "strict-origin-when-cross-origin" always;
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

        # CSP header for InvenTree
        add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self';" always;

        # Rate limiting
        limit_req zone=general burst=20 nodelay;

        # Increase timeouts for large file uploads
        client_max_body_size 100M;
        proxy_read_timeout 300s;
        proxy_connect_timeout 300s;
      '';

      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString inventreePort}";
        extraConfig = ''
          # Note: Host header not set here - Cloudflare already provides it
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_redirect off;

          # WebSocket support for live updates
          proxy_http_version 1.1;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection "upgrade";
        '';
      };

      # Static files served by nginx for better performance
      locations."/static/" = {
        alias = "/var/lib/inventree/static/";
        extraConfig = ''
          expires 30d;
          add_header Cache-Control "public, immutable";
          # Re-add security headers (nginx drops parent headers when using add_header in location)
          add_header X-Frame-Options "SAMEORIGIN" always;
          add_header X-Content-Type-Options "nosniff" always;
          add_header X-XSS-Protection "1; mode=block" always;
          add_header Referrer-Policy "strict-origin-when-cross-origin" always;
          add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
          add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self';" always;
        '';
      };

      # Media files served by nginx
      locations."/media/" = {
        alias = "/var/lib/inventree/media/";
        extraConfig = ''
          expires 7d;
          add_header Cache-Control "public";
          # Re-add security headers
          add_header X-Frame-Options "SAMEORIGIN" always;
          add_header X-Content-Type-Options "nosniff" always;
          add_header X-XSS-Protection "1; mode=block" always;
          add_header Referrer-Policy "strict-origin-when-cross-origin" always;
          add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
          add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self';" always;
        '';
      };
    };

    # Nightly database backup
    systemd.services.inventree-backup = {
      description = "Nightly InvenTree PostgreSQL backup";
      serviceConfig = {
        Type = "oneshot";
        User = "postgres";
        ExecStart = ''
          ${pkgs.postgresql_16}/bin/pg_dump inventree | \
          ${pkgs.gzip}/bin/gzip > /var/backups/inventree/inventree-$(${pkgs.coreutils}/bin/date +\%Y-\%m-\%d).sql.gz
        '';
      };
    };

    systemd.timers.inventree-backup = {
      description = "Nightly InvenTree backup timer";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        Unit = "inventree-backup.service";
      };
    };

    # Backup rotation (keep 30 days)
    systemd.services.inventree-backup-rotate = {
      description = "Rotate old InvenTree backups";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = ''
          ${pkgs.findutils}/bin/find /var/backups/inventree -name "inventree-*.sql.gz" -mtime +30 -delete
        '';
      };
    };

    systemd.timers.inventree-backup-rotate = {
      description = "Weekly backup rotation";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "weekly";
        Persistent = true;
        Unit = "inventree-backup-rotate.service";
      };
    };

    # Persistence configuration for impermanence
    environment.persistence."/nix/persist" = {
      directories = [
        "/var/lib/inventree"
        "/var/lib/postgresql"
        "/var/lib/redis-inventree"
        {
          directory = "/var/backups/inventree";
          mode = "0700";
        }
      ];
    };

    # Ensure backup directory exists and copy custom email backend
    systemd.tmpfiles.rules = [
      "d /var/backups/inventree 0700 root root -"
      "C /var/lib/inventree/inventree_email_backend.py 0644 inventree inventree - ${./inventree_email_backend.py}"
    ];
  };

  # Keep the researchRelay.inventree.enable option for compatibility
  options.services.researchRelay.inventree = {
    enable = lib.mkEnableOption "InvenTree inventory management service (nixos-inventree module)";
  };
}
