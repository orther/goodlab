# PDF-intake service for vendor price sheet management
# FastAPI + Celery + Redis stack for parsing vendor PDFs and updating Odoo
{
  config,
  pkgs,
  lib,
  ...
}: let
  pdfIntakePort = 8070;
  domain = "research-relay.com";

  # Check if secrets are available (not in CI/dev)
  secretsExist = builtins.hasAttr "research-relay/pdf-intake/redis-password" config.sops.secrets;

  # Python environment for PDF-intake service
  # Note: Minimal environment - additional packages like pandas/pypdf2 can be installed via pip
  pythonEnv = pkgs.python311.withPackages (ps:
    with ps; [
      fastapi
      uvicorn
      (celery.overridePythonAttrs (_old: {
        # Remove optional test dependencies that pull in matplotlib/tkinter
        nativeCheckInputs = [];
        doCheck = false;
      }))
      redis
      requests
      pydantic
      # pandas excluded to avoid matplotlib/tk dependencies on server
      # pypdf2 not in nixpkgs - install via pip in production
    ]);
in {
  config = lib.mkIf config.services.researchRelay.pdfIntake.enable {
    # Redis for Celery broker/backend
    services.redis.servers.pdf-intake = {
      enable = true;
      port = 6380;
      bind = "127.0.0.1";
      requirePassFile =
        if secretsExist
        then config.sops.secrets."research-relay/pdf-intake/redis-password".path
        else pkgs.writeText "dummy-redis-pass" "dummy-password-for-ci";
    };

    # PDF-intake FastAPI service
    systemd.services.pdf-intake-api = {
      description = "PDF Intake FastAPI service";
      after = ["network.target" "redis-pdf-intake.service"];
      wants = ["redis-pdf-intake.service"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        Type = "simple";
        User = "pdf-intake";
        Group = "pdf-intake";
        WorkingDirectory = "/var/lib/pdf-intake";
        ExecStart = ''
          ${pythonEnv}/bin/uvicorn app.main:app \
            --host 127.0.0.1 \
            --port ${toString pdfIntakePort} \
            --workers 2
        '';
        Restart = "on-failure";
        RestartSec = "10s";

        # Hardening
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = ["/var/lib/pdf-intake" "/var/log/pdf-intake"];
        NoNewPrivileges = true;
      };

      environment = {
        REDIS_URL = "redis://127.0.0.1:6380";
        REDIS_PASSWORD_FILE =
          if secretsExist
          then config.sops.secrets."research-relay/pdf-intake/redis-password".path
          else toString (pkgs.writeText "dummy-redis-pass" "dummy");
        ODOO_URL = "http://localhost:8069";
        ODOO_DB = "odoo";
        ODOO_USERNAME_FILE =
          if secretsExist
          then config.sops.secrets."research-relay/pdf-intake/odoo-rpc-user".path
          else toString (pkgs.writeText "dummy-odoo-user" "dummy");
        ODOO_PASSWORD_FILE =
          if secretsExist
          then config.sops.secrets."research-relay/pdf-intake/odoo-rpc-password".path
          else toString (pkgs.writeText "dummy-odoo-pass" "dummy");
        API_TOKEN_FILE =
          if secretsExist
          then config.sops.secrets."research-relay/pdf-intake/api-token".path
          else toString (pkgs.writeText "dummy-api-token" "dummy");
        UPLOAD_DIR = "/var/lib/pdf-intake/uploads";
        PARSED_DIR = "/var/lib/pdf-intake/parsed";
      };
    };

    # Celery worker for async PDF processing
    systemd.services.pdf-intake-worker = {
      description = "PDF Intake Celery worker";
      after = ["network.target" "redis-pdf-intake.service"];
      wants = ["redis-pdf-intake.service"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        Type = "simple";
        User = "pdf-intake";
        Group = "pdf-intake";
        WorkingDirectory = "/var/lib/pdf-intake";
        ExecStart = ''
          ${pythonEnv}/bin/celery -A app.celery worker \
            --loglevel=info \
            --concurrency=2
        '';
        Restart = "on-failure";
        RestartSec = "10s";

        # Hardening
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = ["/var/lib/pdf-intake" "/var/log/pdf-intake"];
        NoNewPrivileges = true;
      };

      environment = {
        REDIS_URL = "redis://127.0.0.1:6380";
        REDIS_PASSWORD_FILE =
          if secretsExist
          then config.sops.secrets."research-relay/pdf-intake/redis-password".path
          else toString (pkgs.writeText "dummy-redis-pass" "dummy");
        ODOO_URL = "http://localhost:8069";
        ODOO_DB = "odoo";
        ODOO_USERNAME_FILE =
          if secretsExist
          then config.sops.secrets."research-relay/pdf-intake/odoo-rpc-user".path
          else toString (pkgs.writeText "dummy-odoo-user" "dummy");
        ODOO_PASSWORD_FILE =
          if secretsExist
          then config.sops.secrets."research-relay/pdf-intake/odoo-rpc-password".path
          else toString (pkgs.writeText "dummy-odoo-pass" "dummy");
      };
    };

    # User and group
    users.users.pdf-intake = {
      isSystemUser = true;
      group = "pdf-intake";
      home = "/var/lib/pdf-intake";
      createHome = true;
    };
    users.groups.pdf-intake = {};

    # Nginx reverse proxy (internal only, accessed via VPN/SSH tunnel)
    services.nginx.virtualHosts."pdf-intake.${domain}" = {
      # No SSL - internal service only
      listen = [
        {
          addr = "127.0.0.1";
          port = 8071;
        }
      ];

      extraConfig = ''
        # Internal service - strict token auth required
        limit_req zone=api burst=20 nodelay;

        # Max upload size for large PDFs
        client_max_body_size 50M;
      '';

      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString pdfIntakePort}";
        extraConfig = ''
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header Host $host;

          # Token authentication is handled by the FastAPI application
        '';
      };
    };

    # Create application structure
    systemd.tmpfiles.rules = [
      "d /var/lib/pdf-intake 0750 pdf-intake pdf-intake -"
      "d /var/lib/pdf-intake/uploads 0750 pdf-intake pdf-intake -"
      "d /var/lib/pdf-intake/parsed 0750 pdf-intake pdf-intake -"
      "d /var/lib/pdf-intake/app 0750 pdf-intake pdf-intake -"
      "d /var/log/pdf-intake 0750 pdf-intake pdf-intake -"
    ];

    # Persistence
    environment.persistence."/nix/persist" = {
      directories = [
        "/var/lib/pdf-intake"
        "/var/log/pdf-intake"
      ];
    };
  };

  # Module options
  options.services.researchRelay.pdfIntake = {
    enable = lib.mkEnableOption "Research Relay PDF intake service for vendor price management";
  };
}
