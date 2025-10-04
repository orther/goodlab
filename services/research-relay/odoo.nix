# Odoo eCommerce service for Research Relay
# Includes PostgreSQL database and nginx reverse proxy with Cloudflare origin certs
{
  config,
  pkgs,
  lib,
  ...
}: let
  odooPort = 8069;
  domain = "research-relay.com";
in {
  config = lib.mkIf config.services.researchRelay.odoo.enable {
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
      authentication = ''
        local odoo odoo peer map=odoo
        local all postgres peer
      '';
      identMap = ''
        odoo odoo odoo
        odoo root postgres
      '';
    };

    # Odoo service (Community edition)
    systemd.services.odoo = {
      description = "Odoo Community ERP/eCommerce";
      after = ["network.target" "postgresql.service"];
      wants = ["postgresql.service"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        Type = "simple";
        User = "odoo";
        Group = "odoo";
        ExecStart = "${pkgs.odoo}/bin/odoo --config /var/lib/odoo/odoo.conf";
        Restart = "on-failure";
        RestartSec = "10s";

        # Hardening
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = ["/var/lib/odoo" "/var/log/odoo"];
        NoNewPrivileges = true;
      };

      preStart = ''
        # Ensure directories exist
        mkdir -p /var/lib/odoo/addons
        mkdir -p /var/log/odoo

        # Generate config if not exists
        if [ ! -f /var/lib/odoo/odoo.conf ]; then
          cat > /var/lib/odoo/odoo.conf <<EOF
        [options]
        admin_passwd = \$ODOO_ADMIN_PASSWORD
        db_host = False
        db_port = False
        db_user = odoo
        db_password = False
        addons_path = /var/lib/odoo/addons,${pkgs.odoo}/lib/python3.11/site-packages/odoo/addons
        data_dir = /var/lib/odoo/data
        logfile = /var/log/odoo/odoo.log
        http_port = ${toString odooPort}
        proxy_mode = True
        EOF
        fi

        # Set permissions
        chown -R odoo:odoo /var/lib/odoo /var/log/odoo
      '';

      environment = {
        ODOO_ADMIN_PASSWORD = config.sops.secrets."research-relay/odoo/admin-password".path;
      };
    };

    # Odoo user and group
    users.users.odoo = {
      isSystemUser = true;
      group = "odoo";
      home = "/var/lib/odoo";
      createHome = true;
    };
    users.groups.odoo = {};

    # Nginx reverse proxy with Cloudflare origin cert
    services.nginx.virtualHosts."${domain}" = {
      forceSSL = true;
      sslCertificate = config.sops.secrets."research-relay/cloudflare-origin-cert".path;
      sslCertificateKey = config.sops.secrets."research-relay/cloudflare-origin-key".path;

      extraConfig = ''
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
      forceSSL = true;
      sslCertificate = config.sops.secrets."research-relay/cloudflare-origin-cert".path;
      sslCertificateKey = config.sops.secrets."research-relay/cloudflare-origin-key".path;
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
