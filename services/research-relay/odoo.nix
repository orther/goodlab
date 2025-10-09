# Odoo eCommerce service for Research Relay
# Includes PostgreSQL database and nginx reverse proxy with Cloudflare origin certs
# NOTE: This module uses Docker for Odoo since it's not packaged in nixpkgs
{
  config,
  pkgs,
  lib,
  ...
}: let
  odooPort = 8069;
  domain = "research-relay.com";
  odooVersion = "17.0";

  # Check if secrets are available (not in CI/dev)
  secretsExist = builtins.hasAttr "research-relay/cloudflare-origin-cert" config.sops.secrets;
in {
  config = lib.mkIf config.services.researchRelay.odoo.enable {
    # Enable Docker for Odoo container
    virtualisation.docker = {
      enable = true;
      autoPrune = {
        enable = true;
        dates = "weekly";
      };
    };

    # Allow PostgreSQL access from Docker bridge network
    networking.firewall.extraCommands = ''
      iptables -A nixos-fw -p tcp -s 172.17.0.0/16 --dport 5432 -j ACCEPT
    '';

    # PostgreSQL database for Odoo
    services.postgresql = {
      enable = true;
      package = pkgs.postgresql_16;
      ensureDatabases = ["odoo"];
      ensureUsers = [
        {
          name = "odoo";
          ensureDBOwnership = true;
        }
      ];
      # Listen on all interfaces for Docker containers
      settings = {
        listen_addresses = lib.mkForce "*";
      };
      authentication = ''
        # Allow Docker containers (on bridge network 172.17.0.0/16)
        # Allow any database for initial connection checks, then switch to odoo database
        host all odoo 172.17.0.0/16 md5
        # Allow localhost with password
        host odoo odoo 127.0.0.1/32 scram-sha-256
        # Allow local peer authentication
        local odoo odoo peer map=odoo
        local all postgres peer
      '';
      identMap = ''
        odoo odoo odoo
        odoo root postgres
      '';
      # Initialize odoo user password
      initialScript = pkgs.writeText "init-odoo-db.sql" ''
        ALTER USER odoo WITH PASSWORD 'odoo';
      '';
    };

    # Odoo service via Docker
    systemd.services.odoo = {
      description = "Odoo Community ERP/eCommerce (Docker)";
      after = ["network.target" "postgresql.service" "docker.service"];
      wants = ["postgresql.service" "docker.service"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        WorkingDirectory = "/var/lib/odoo";
        ExecStartPre = pkgs.writeShellScript "odoo-pre" ''
          set -euo pipefail
          mkdir -p /var/lib/odoo/{addons,data,config}

          # Create Odoo config
          cat > /var/lib/odoo/config/odoo.conf <<EOF
          [options]
          admin_passwd = ${
            if secretsExist
            then "$(cat ${config.sops.secrets."research-relay/odoo/admin-password".path})"
            else "admin"
          }
          db_host = 172.17.0.1
          db_port = 5432
          db_user = odoo
          db_password = odoo
          addons_path = /mnt/extra-addons
          data_dir = /var/lib/odoo
          logfile =
          http_port = ${toString odooPort}
          proxy_mode = True
          EOF
        '';
        ExecStart = ''
          ${pkgs.docker}/bin/docker run --rm --name odoo \
            -p 127.0.0.1:${toString odooPort}:8069 \
            -v /var/lib/odoo/addons:/mnt/extra-addons \
            -v /var/lib/odoo/data:/var/lib/odoo \
            -v /var/lib/odoo/config:/etc/odoo \
            odoo:${odooVersion}
        '';
        ExecStop = "${pkgs.docker}/bin/docker stop odoo";
        Restart = "on-failure";
        RestartSec = "10s";
      };
    };

    # Ensure data directories exist with proper permissions
    systemd.tmpfiles.rules = [
      "d /var/lib/odoo 0750 root root -"
      "d /var/lib/odoo/addons 0750 root root -"
      "d /var/lib/odoo/data 0750 root root -"
      "d /var/lib/odoo/config 0750 root root -"
      "d /var/backups/research-relay 0700 root root -"
    ];

    # Nginx reverse proxy with Cloudflare origin cert
    services.nginx.virtualHosts."${domain}" = {
      forceSSL = secretsExist;
      sslCertificate = lib.mkIf secretsExist config.sops.secrets."research-relay/cloudflare-origin-cert".path;
      sslCertificateKey = lib.mkIf secretsExist config.sops.secrets."research-relay/cloudflare-origin-key".path;

      extraConfig = ''
        # Security headers (must repeat global headers due to add_header behavior)
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header Referrer-Policy "strict-origin-when-cross-origin" always;

        # HSTS header
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

        # CSP header for eCommerce
        add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self';" always;

        # Rate limiting
        limit_req zone=general burst=20 nodelay;
      '';

      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString odooPort}";
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

      # US-only checkout enforcement (WAF handles primary blocking)
      locations."~ ^/shop/(cart|checkout)" = {
        proxyPass = "http://127.0.0.1:${toString odooPort}";
        extraConfig = ''
          # Cloudflare country header check (backup to WAF)
          if ($http_cf_ipcountry != "US") {
            return 403 "Access denied: US only";
          }

          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header Host $host;

          limit_req zone=general burst=10 nodelay;
        '';
      };
    };

    # www subdomain redirect
    services.nginx.virtualHosts."www.${domain}" = {
      forceSSL = secretsExist;
      sslCertificate = lib.mkIf secretsExist config.sops.secrets."research-relay/cloudflare-origin-cert".path;
      sslCertificateKey = lib.mkIf secretsExist config.sops.secrets."research-relay/cloudflare-origin-key".path;
      globalRedirect = domain;
    };

    # Nightly database backup
    systemd.services.odoo-backup = {
      description = "Nightly Odoo PostgreSQL backup";
      serviceConfig = {
        Type = "oneshot";
        User = "postgres";
        ExecStart = ''
          ${pkgs.postgresql_16}/bin/pg_dump odoo | \
          ${pkgs.gzip}/bin/gzip > /var/backups/research-relay/odoo-$(${pkgs.coreutils}/bin/date +\%Y-\%m-\%d).sql.gz
        '';
      };
    };

    systemd.timers.odoo-backup = {
      description = "Nightly Odoo backup timer";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        Unit = "odoo-backup.service";
      };
    };

    # Backup rotation (keep 30 days)
    systemd.services.odoo-backup-rotate = {
      description = "Rotate old Odoo backups";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = ''
          ${pkgs.findutils}/bin/find /var/backups/research-relay -name "odoo-*.sql.gz" -mtime +30 -delete
        '';
      };
    };

    systemd.timers.odoo-backup-rotate = {
      description = "Weekly backup rotation";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "weekly";
        Persistent = true;
        Unit = "odoo-backup-rotate.service";
      };
    };

    # Persistence configuration
    environment.persistence."/nix/persist" = {
      directories = [
        "/var/lib/odoo"
        "/var/lib/postgresql"
        "/var/log/odoo"
        {
          directory = "/var/backups/research-relay";
          mode = "0700";
        }
      ];
    };
  };

  # Module options
  options.services.researchRelay.odoo = {
    enable = lib.mkEnableOption "Research Relay Odoo eCommerce service";
  };
}
