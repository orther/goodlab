# BTCPay Server for Research Relay crypto payments
# Runs on zinc host via Docker/OCI containers
{
  config,
  pkgs,
  lib,
  ...
}: let
  domain = "pay.research-relay.com";
  btcpayPort = 23000;

  # Check if secrets are available (not in CI/dev)
  secretsExist = builtins.hasAttr "research-relay/cloudflare-origin-cert" config.sops.secrets;
in {
  config = lib.mkIf config.services.researchRelay.btcpay.enable {
    # Enable Docker for BTCPay stack
    virtualisation.docker = {
      enable = true;
      autoPrune = {
        enable = true;
        dates = "weekly";
      };
    };

    # BTCPay Server via Docker Compose
    # Using official BTCPayServer/Docker deployment
    systemd.services.btcpay = {
      description = "BTCPay Server";
      after = ["network.target" "docker.service"];
      wants = ["docker.service"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        WorkingDirectory = "/var/lib/btcpay";
        ExecStart = "${pkgs.docker-compose}/bin/docker-compose up -d";
        ExecStop = "${pkgs.docker-compose}/bin/docker-compose down";
        Restart = "on-failure";
        RestartSec = "10s";
      };

      preStart = ''
        mkdir -p /var/lib/btcpay/{btcpay,postgres,nbxplorer,bitcoin,lightning}

        # Generate docker-compose.yml if not exists
        if [ ! -f /var/lib/btcpay/docker-compose.yml ]; then
          cat > /var/lib/btcpay/docker-compose.yml <<'EOF'
        version: "3"
        services:
          postgres:
            image: postgres:16-alpine
            restart: unless-stopped
            environment:
              POSTGRES_USER: btcpay
              POSTGRES_DB: btcpay
              POSTGRES_PASSWORD_FILE: /run/secrets/db_password
            volumes:
              - /var/lib/btcpay/postgres:/var/lib/postgresql/data
            secrets:
              - db_password

          nbxplorer:
            image: nicolasdorier/nbxplorer:latest
            restart: unless-stopped
            environment:
              NBXPLORER_NETWORK: mainnet
              NBXPLORER_BIND: 0.0.0.0:32838
              NBXPLORER_CHAINS: btc
              NBXPLORER_BTCRPCURL: http://bitcoin:8332
              NBXPLORER_BTCNODEENDPOINT: bitcoin:8333
            volumes:
              - /var/lib/btcpay/nbxplorer:/datadir
            depends_on:
              - bitcoin

          bitcoin:
            image: btcpayserver/bitcoin:27.0
            restart: unless-stopped
            environment:
              BITCOIN_NETWORK: mainnet
              BITCOIN_EXTRA_ARGS: |
                rpcuser=btcpay
                rpcpassword=$BITCOIN_RPC_PASSWORD
                rpcallowip=0.0.0.0/0
                zmqpubrawblock=tcp://0.0.0.0:28332
                zmqpubrawtx=tcp://0.0.0.0:28333
            volumes:
              - /var/lib/btcpay/bitcoin:/data
            ports:
              - "8333:8333"

          btcpayserver:
            image: btcpayserver/btcpayserver:latest
            restart: unless-stopped
            environment:
              BTCPAY_POSTGRES: "User ID=btcpay;Host=postgres;Port=5432;Database=btcpay;Password=$POSTGRES_PASSWORD"
              BTCPAY_NETWORK: mainnet
              BTCPAY_BIND: 0.0.0.0:${toString btcpayPort}
              BTCPAY_EXTERNALURL: https://${domain}
              BTCPAY_ROOTPATH: /
              BTCPAY_CHAINS: btc
              BTCPAY_BTCEXPLORERURL: http://nbxplorer:32838
            volumes:
              - /var/lib/btcpay/btcpay:/datadir
            ports:
              - "${toString btcpayPort}:${toString btcpayPort}"
            depends_on:
              - postgres
              - nbxplorer

        secrets:
          db_password:
            file: /run/secrets/btcpay-db-password
        EOF
        fi

        # Link sops secrets to Docker secrets directory (only if secrets exist)
        ${lib.optionalString secretsExist ''
          mkdir -p /var/lib/btcpay/secrets
          ln -sf ${config.sops.secrets."research-relay/btcpay/db-password".path} /var/lib/btcpay/secrets/db_password
        ''}
      '';
    };

    # Nginx reverse proxy for BTCPay subdomain
    services.nginx.virtualHosts."${domain}" = {
      forceSSL = secretsExist;
      sslCertificate = lib.mkIf secretsExist config.sops.secrets."research-relay/cloudflare-origin-cert".path;
      sslCertificateKey = lib.mkIf secretsExist config.sops.secrets."research-relay/cloudflare-origin-key".path;

      extraConfig = ''
        # HSTS
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

        # Rate limiting for payment API
        limit_req zone=api burst=50 nodelay;
      '';

      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString btcpayPort}";
        extraConfig = ''
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header Host $host;
          proxy_redirect off;

          # WebSocket support for payment notifications
          proxy_http_version 1.1;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection "upgrade";

          # Increased timeouts for blockchain operations
          proxy_connect_timeout 600;
          proxy_send_timeout 600;
          proxy_read_timeout 600;
          send_timeout 600;
        '';
      };
    };

    # BTCPay backup service (wallet seeds + store config)
    systemd.services.btcpay-backup = {
      description = "BTCPay Server backup";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "btcpay-backup" ''
          set -euo pipefail

          BACKUP_DIR="/var/backups/research-relay/btcpay"
          DATE=$(${pkgs.coreutils}/bin/date +%Y-%m-%d)

          mkdir -p "$BACKUP_DIR"

          # Backup BTCPay data directory (includes wallet seeds, store configs)
          ${pkgs.gnutar}/bin/tar czf "$BACKUP_DIR/btcpay-data-$DATE.tar.gz" \
            -C /var/lib/btcpay/btcpay .

          # Backup PostgreSQL database
          ${pkgs.docker}/bin/docker exec btcpay-postgres-1 pg_dump -U btcpay btcpay | \
            ${pkgs.gzip}/bin/gzip > "$BACKUP_DIR/btcpay-db-$DATE.sql.gz"

          # Encrypt backup with age (only if secrets exist)
          ${lib.optionalString secretsExist ''
            ${pkgs.age}/bin/age -r $(cat ${config.sops.secrets."research-relay/backup-age-pubkey".path}) \
              -o "$BACKUP_DIR/btcpay-data-$DATE.tar.gz.age" \
              "$BACKUP_DIR/btcpay-data-$DATE.tar.gz"

            ${pkgs.age}/bin/age -r $(cat ${config.sops.secrets."research-relay/backup-age-pubkey".path}) \
              -o "$BACKUP_DIR/btcpay-db-$DATE.sql.gz.age" \
              "$BACKUP_DIR/btcpay-db-$DATE.sql.gz"

            # Remove unencrypted backups
            rm "$BACKUP_DIR/btcpay-data-$DATE.tar.gz" "$BACKUP_DIR/btcpay-db-$DATE.sql.gz"
          ''}
        '';
      };
    };

    systemd.timers.btcpay-backup = {
      description = "Nightly BTCPay backup";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        Unit = "btcpay-backup.service";
      };
    };

    # Backup rotation (keep 60 days for financial records)
    systemd.services.btcpay-backup-rotate = {
      description = "Rotate old BTCPay backups";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = ''
          ${pkgs.findutils}/bin/find /var/backups/research-relay/btcpay -name "*.age" -mtime +60 -delete
        '';
      };
    };

    systemd.timers.btcpay-backup-rotate = {
      description = "Weekly BTCPay backup rotation";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "weekly";
        Persistent = true;
        Unit = "btcpay-backup-rotate.service";
      };
    };

    # Open Bitcoin P2P port for better node connectivity
    networking.firewall.allowedTCPPorts = [8333];

    # Persistence
    environment.persistence."/nix/persist" = {
      directories = [
        "/var/lib/btcpay"
        "/var/lib/docker"
        {
          directory = "/var/backups/research-relay/btcpay";
          mode = "0700";
        }
      ];
    };
  };

  # Module options
  options.services.researchRelay.btcpay = {
    enable = lib.mkEnableOption "Research Relay BTCPay Server payment gateway";
  };
}
