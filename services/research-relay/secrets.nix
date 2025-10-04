# Research Relay secrets configuration template
# Add these secrets to your secrets/secrets.yaml file
#
# Required secrets structure:
# research-relay:
#   # Cloudflare origin certificates (shared between noir and zinc)
#   cloudflare-origin-cert: |
#     -----BEGIN CERTIFICATE-----
#     ...
#     -----END CERTIFICATE-----
#   cloudflare-origin-key: |
#     -----BEGIN PRIVATE KEY-----
#     ...
#     -----END PRIVATE KEY-----
#
#   # Odoo secrets (noir)
#   odoo:
#     admin-password: "strong-password-here"
#
#   # PDF-intake secrets (noir)
#   pdf-intake:
#     redis-password: "redis-password"
#     odoo-rpc-user: "pdf_intake_service"
#     odoo-rpc-password: "rpc-password"
#     api-token: "secret-token-for-api-auth"
#
#   # BTCPay secrets (zinc)
#   btcpay:
#     db-password: "btcpay-postgres-password"
#     api-key: "btcpay-api-key-for-odoo"
#     webhook-secret: "webhook-signature-secret"
#
#   # Backup encryption
#   backup-age-pubkey: "age1..."
#
{
  config,
  lib,
  ...
}: {
  # Research Relay secrets configuration
  sops.secrets = lib.mkIf (config.services.researchRelay.odoo.enable or config.services.researchRelay.btcpay.enable or config.services.researchRelay.pdfIntake.enable) {
    # Cloudflare origin certificates (both hosts)
    "research-relay/cloudflare-origin-cert" = {
      sopsFile = ../../secrets/research-relay.yaml;
      mode = "0440";
      group = "nginx";
    };

    "research-relay/cloudflare-origin-key" = {
      sopsFile = ../../secrets/research-relay.yaml;
      mode = "0440";
      group = "nginx";
    };

    # Odoo secrets (noir only)
    "research-relay/odoo/admin-password" = lib.mkIf config.services.researchRelay.odoo.enable {
      sopsFile = ../../secrets/research-relay.yaml;
      owner = "odoo";
      mode = "0400";
    };

    # PDF-intake secrets (noir only)
    "research-relay/pdf-intake/redis-password" = lib.mkIf config.services.researchRelay.pdfIntake.enable {
      sopsFile = ../../secrets/research-relay.yaml;
      owner = "pdf-intake";
      mode = "0400";
    };

    "research-relay/pdf-intake/odoo-rpc-user" = lib.mkIf config.services.researchRelay.pdfIntake.enable {
      sopsFile = ../../secrets/research-relay.yaml;
      owner = "pdf-intake";
      mode = "0400";
    };

    "research-relay/pdf-intake/odoo-rpc-password" = lib.mkIf config.services.researchRelay.pdfIntake.enable {
      sopsFile = ../../secrets/research-relay.yaml;
      owner = "pdf-intake";
      mode = "0400";
    };

    "research-relay/pdf-intake/api-token" = lib.mkIf config.services.researchRelay.pdfIntake.enable {
      sopsFile = ../../secrets/research-relay.yaml;
      owner = "pdf-intake";
      mode = "0400";
    };

    # BTCPay secrets (zinc only)
    "research-relay/btcpay/db-password" = lib.mkIf config.services.researchRelay.btcpay.enable {
      sopsFile = ../../secrets/research-relay.yaml;
      mode = "0400";
    };

    "research-relay/btcpay/api-key" = lib.mkIf config.services.researchRelay.btcpay.enable {
      sopsFile = ../../secrets/research-relay.yaml;
      mode = "0400";
    };

    "research-relay/btcpay/webhook-secret" = lib.mkIf config.services.researchRelay.btcpay.enable {
      sopsFile = ../../secrets/research-relay.yaml;
      mode = "0400";
    };

    # Backup encryption key (both hosts)
    "research-relay/backup-age-pubkey" = lib.mkIf (config.services.researchRelay.odoo.enable or config.services.researchRelay.btcpay.enable) {
      sopsFile = ../../secrets/research-relay.yaml;
      mode = "0444";
    };
  };
}
