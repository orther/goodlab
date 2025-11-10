# InvenTree inventory management service for homelab
# Includes PostgreSQL database, Redis cache, and nginx reverse proxy with ACME certs
# NOTE: This module uses Docker for InvenTree since it's not packaged in nixpkgs
{
  config,
  pkgs,
  lib,
  ...
}: let
  inventreePort = 8000;
  inventreeDomain = "inventree.orther.dev";
  inventreeTag = "stable"; # stable, latest, or specific version tag

  # Check if secrets are available (not in CI/dev)
  secretsExist = builtins.hasAttr "research-relay/inventree/admin-password" config.sops.secrets;
in {
  config = lib.mkIf config.services.researchRelay.inventree.enable {
    # Enable Docker for InvenTree containers
    virtualisation.docker = {
      enable = true;
      autoPrune = {
        enable = true;
        dates = "weekly";
      };
    };

    # Allow PostgreSQL and Redis access from Docker bridge network
    networking.firewall.extraCommands = ''
      iptables -A nixos-fw -p tcp -s 172.17.0.0/16 --dport 5432 -j ACCEPT
      iptables -A nixos-fw -p tcp -s 172.17.0.0/16 --dport 6379 -j ACCEPT
    '';

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
      # Listen on all interfaces for Docker containers
      settings = {
        listen_addresses = lib.mkForce "*";
      };
      authentication = ''
        # Allow Docker containers (on bridge network 172.17.0.0/16)
        host all inventree 172.17.0.0/16 md5
        # Allow localhost with password
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
      bind = "0.0.0.0"; # Allow Docker bridge network access
      requirePass = "inventree";
      settings = {
        maxmemory = "256mb";
        maxmemory-policy = "allkeys-lru";
      };
    };

    # InvenTree server via Docker
    systemd.services.inventree-server = {
      description = "InvenTree Inventory Management Server (Docker)";
      after = ["network.target" "postgresql.service" "redis-inventree.service" "docker.service"];
      wants = ["postgresql.service" "redis-inventree.service" "docker.service"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        WorkingDirectory = "/var/lib/inventree";
        ExecStartPre = pkgs.writeShellScript "inventree-pre" ''
          set -euo pipefail
          mkdir -p /var/lib/inventree/data

          # Create InvenTree config.yaml
          cat > /var/lib/inventree/data/config.yaml <<EOF
          # InvenTree Configuration File
          debug: false
          log_level: WARNING

          # Database configuration
          database:
            ENGINE: django.db.backends.postgresql
            NAME: inventree
            USER: inventree
            PASSWORD: inventree
            HOST: 172.17.0.1
            PORT: 5432

          # Cache configuration
          cache:
            host: 172.17.0.1
            port: 6379
            password: inventree

          # Media and static files
          media_root: /home/inventree/data/media
          static_root: /home/inventree/data/static

          # Plugin support
          plugins_enabled: true
          plugin_dir: /home/inventree/data/plugins

          # Security
          secret_key_file: /home/inventree/data/secret_key.txt
          allowed_hosts:
            - ${inventreeDomain}
            - localhost
            - 127.0.0.1

          # Admin user
          inventree_admin_user: ${
            if secretsExist
            then "$(cat ${config.sops.secrets."research-relay/inventree/admin-user".path})"
            else "admin"
          }
          inventree_admin_password: ${
            if secretsExist
            then "$(cat ${config.sops.secrets."research-relay/inventree/admin-password".path})"
            else "admin"
          }
          inventree_admin_email: ${
            if secretsExist
            then "$(cat ${config.sops.secrets."research-relay/inventree/admin-email".path})"
            else "admin@example.com"
          }

          # Auto-updates
          inventree_auto_update: true
          EOF

          # Wait for PostgreSQL to be ready
          while ! ${pkgs.postgresql_16}/bin/pg_isready -h 127.0.0.1 -p 5432 -U inventree; do
            echo "Waiting for PostgreSQL..."
            sleep 2
          done

          # Wait for Redis to be ready
          while ! ${pkgs.redis}/bin/redis-cli -h 127.0.0.1 -p 6379 -a inventree ping > /dev/null 2>&1; do
            echo "Waiting for Redis..."
            sleep 2
          done

          # Run database migrations on first start
          if [ ! -f /var/lib/inventree/.initialized ]; then
            ${pkgs.docker}/bin/docker run --rm \
              -v /var/lib/inventree/data:/home/inventree/data \
              -e INVENTREE_CONFIG_FILE=/home/inventree/data/config.yaml \
              inventree/inventree:${inventreeTag} \
              invoke update --skip-backup
            touch /var/lib/inventree/.initialized
          fi
        '';
        ExecStart = ''
          ${pkgs.docker}/bin/docker run --rm --name inventree-server \
            -p 127.0.0.1:${toString inventreePort}:8000 \
            -v /var/lib/inventree/data:/home/inventree/data \
            -e INVENTREE_CONFIG_FILE=/home/inventree/data/config.yaml \
            -e INVENTREE_GUNICORN_TIMEOUT=90 \
            inventree/inventree:${inventreeTag}
        '';
        ExecStop = "${pkgs.docker}/bin/docker stop inventree-server";
        Restart = "on-failure";
        RestartSec = "10s";
      };
    };

    # InvenTree background worker via Docker
    systemd.services.inventree-worker = {
      description = "InvenTree Background Worker (Docker)";
      after = ["inventree-server.service"];
      wants = ["inventree-server.service"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        WorkingDirectory = "/var/lib/inventree";
        ExecStart = ''
          ${pkgs.docker}/bin/docker run --rm --name inventree-worker \
            -v /var/lib/inventree/data:/home/inventree/data \
            -e INVENTREE_CONFIG_FILE=/home/inventree/data/config.yaml \
            inventree/inventree:${inventreeTag} \
            invoke worker
        '';
        ExecStop = "${pkgs.docker}/bin/docker stop inventree-worker";
        Restart = "on-failure";
        RestartSec = "10s";
      };
    };

    # Ensure data directories exist with proper permissions
    # InvenTree container runs as UID 1000, GID 1000
    systemd.tmpfiles.rules = [
      "d /var/lib/inventree 0755 1000 1000 -"
      "d /var/lib/inventree/data 0755 1000 1000 -"
      "d /var/backups/inventree 0700 root root -"
    ];

    # ACME certificate for inventree.orther.dev using Cloudflare DNS-01 challenge
    # This allows Let's Encrypt validation via DNS instead of HTTP, perfect for internal services
    security.acme.certs."${inventreeDomain}" = {
      domain = inventreeDomain;
      dnsProvider = "cloudflare";
      credentialsFile = config.sops.secrets."cloudflare/acme-dns-token".path;
      group = "nginx";
    };

    # Nginx reverse proxy for internal homelab access
    services.nginx.virtualHosts."${inventreeDomain}" = {
      forceSSL = true;
      useACMEHost = inventreeDomain;

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
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header Host $host;
          proxy_redirect off;

          # WebSocket support for live updates
          proxy_http_version 1.1;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection "upgrade";
        '';
      };

      # Static files served by nginx
      locations."/static/" = {
        alias = "/var/lib/inventree/data/static/";
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
        alias = "/var/lib/inventree/data/media/";
        extraConfig = ''
          expires 7d;
          add_header Cache-Control "public";
          # Re-add security headers (nginx drops parent headers when using add_header in location)
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

    # Persistence configuration
    environment.persistence."/nix/persist" = {
      directories = [
        "/var/lib/inventree"
        "/var/lib/postgresql"
        "/var/lib/redis-inventree"
        "/var/log/inventree"
        {
          directory = "/var/backups/inventree";
          mode = "0700";
        }
      ];
    };
  };

  # Module options
  options.services.researchRelay.inventree = {
    enable = lib.mkEnableOption "InvenTree inventory management service";
  };
}
