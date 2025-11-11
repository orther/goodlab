# Research Relay secrets configuration template
# Add these secrets to your secrets/secrets.yaml and secrets/research-relay.yaml files
#
# Required in secrets/secrets.yaml:
# cloudflare:
#   # API token for ACME DNS-01 challenges (format: CF_DNS_API_TOKEN=<token>)
#   # Create at: https://dash.cloudflare.com/profile/api-tokens
#   # Permissions needed: Zone:DNS:Edit for target zone
#   acme-dns-token: |
#     CF_DNS_API_TOKEN=your_cloudflare_api_token_here
#
# Required in secrets/research-relay.yaml:
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
#   # InvenTree secrets (noir)
#   inventree:
#     admin-user: "admin"
#     admin-password: "strong-password-here"
#     admin-email: "admin@orther.dev"
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
}: let
  hasResearchRelay = builtins.hasAttr "researchRelay" config.services;
  hasOdoo = hasResearchRelay && builtins.hasAttr "odoo" config.services.researchRelay;
  hasInvenTree = hasResearchRelay && builtins.hasAttr "inventree" config.services.researchRelay;
  hasBtcpay = hasResearchRelay && builtins.hasAttr "btcpay" config.services.researchRelay;
  hasPdfIntake = hasResearchRelay && builtins.hasAttr "pdfIntake" config.services.researchRelay;

  anyServiceEnabled =
    (hasOdoo && config.services.researchRelay.odoo.enable)
    || (hasInvenTree && config.services.researchRelay.inventree.enable)
    || (hasBtcpay && config.services.researchRelay.btcpay.enable)
    || (hasPdfIntake && config.services.researchRelay.pdfIntake.enable);

  # Check if secrets files exist (not present in CI/dev environments)
  researchRelaySecretsFile = ../../secrets/research-relay.yaml;
  researchRelaySecretsExist = builtins.pathExists researchRelaySecretsFile;

  globalSecretsFile = ../../secrets/secrets.yaml;
  globalSecretsExist = builtins.pathExists globalSecretsFile;
in {
  # Research Relay secrets configuration
  # Only configure secrets if services are enabled AND secrets file exists
  sops.secrets = lib.mkIf anyServiceEnabled {
    # Cloudflare origin certificates (both hosts)
    "research-relay/cloudflare-origin-cert" = lib.mkIf researchRelaySecretsExist {
      sopsFile = researchRelaySecretsFile;
      mode = "0440";
      group = "nginx";
    };

    "research-relay/cloudflare-origin-key" = lib.mkIf researchRelaySecretsExist {
      sopsFile = researchRelaySecretsFile;
      mode = "0440";
      group = "nginx";
    };

    # Cloudflare API token for ACME DNS-01 challenges
    # Used by both Odoo and InvenTree for internal DNS domains
    "cloudflare/acme-dns-token" = lib.mkIf (globalSecretsExist
      && (
        (hasOdoo && config.services.researchRelay.odoo.enable)
        || (hasInvenTree && config.services.researchRelay.inventree.enable)
      )) {
      sopsFile = globalSecretsFile;
      mode = "0400";
      owner = "acme";
    };

    # Odoo secrets (noir only)
    "research-relay/odoo/admin-password" = lib.mkIf (researchRelaySecretsExist && hasOdoo && config.services.researchRelay.odoo.enable) {
      sopsFile = researchRelaySecretsFile;
      owner = "odoo";
      mode = "0400";
    };

    # InvenTree secrets (noir only) - stored in global secrets.yaml
    "research-relay/inventree/admin-user" = lib.mkIf (globalSecretsExist && hasInvenTree && config.services.researchRelay.inventree.enable) {
      sopsFile = globalSecretsFile;
      mode = "0444";
    };

    "research-relay/inventree/admin-password" = lib.mkIf (globalSecretsExist && hasInvenTree && config.services.researchRelay.inventree.enable) {
      sopsFile = globalSecretsFile;
      mode = "0400";
    };

    "research-relay/inventree/admin-email" = lib.mkIf (globalSecretsExist && hasInvenTree && config.services.researchRelay.inventree.enable) {
      sopsFile = globalSecretsFile;
      mode = "0444";
    };

    # PDF-intake secrets (noir only)
    "research-relay/pdf-intake/redis-password" = lib.mkIf (researchRelaySecretsExist && hasPdfIntake && config.services.researchRelay.pdfIntake.enable) {
      sopsFile = researchRelaySecretsFile;
      owner = "pdf-intake";
      mode = "0400";
    };

    "research-relay/pdf-intake/odoo-rpc-user" = lib.mkIf (researchRelaySecretsExist && hasPdfIntake && config.services.researchRelay.pdfIntake.enable) {
      sopsFile = researchRelaySecretsFile;
      owner = "pdf-intake";
      mode = "0400";
    };

    "research-relay/pdf-intake/odoo-rpc-password" = lib.mkIf (researchRelaySecretsExist && hasPdfIntake && config.services.researchRelay.pdfIntake.enable) {
      sopsFile = researchRelaySecretsFile;
      owner = "pdf-intake";
      mode = "0400";
    };

    "research-relay/pdf-intake/api-token" = lib.mkIf (researchRelaySecretsExist && hasPdfIntake && config.services.researchRelay.pdfIntake.enable) {
      sopsFile = researchRelaySecretsFile;
      owner = "pdf-intake";
      mode = "0400";
    };

    # BTCPay secrets (zinc only)
    "research-relay/btcpay/db-password" = lib.mkIf (researchRelaySecretsExist && hasBtcpay && config.services.researchRelay.btcpay.enable) {
      sopsFile = researchRelaySecretsFile;
      mode = "0400";
    };

    "research-relay/btcpay/api-key" = lib.mkIf (researchRelaySecretsExist && hasBtcpay && config.services.researchRelay.btcpay.enable) {
      sopsFile = researchRelaySecretsFile;
      mode = "0400";
    };

    "research-relay/btcpay/webhook-secret" = lib.mkIf (researchRelaySecretsExist && hasBtcpay && config.services.researchRelay.btcpay.enable) {
      sopsFile = researchRelaySecretsFile;
      mode = "0400";
    };

    # Backup encryption key (both hosts)
    "research-relay/backup-age-pubkey" = lib.mkIf (researchRelaySecretsExist && anyServiceEnabled) {
      sopsFile = researchRelaySecretsFile;
      mode = "0444";
    };
  };
}
