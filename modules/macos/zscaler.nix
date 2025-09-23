{ config, pkgs, lib, ... }:

let
  cfg = config.local.zscaler;

  # Certificate extraction script that exports certificates from macOS keychain
  extractCertificates = pkgs.writeShellScript "extract-certificates" ''
    set -euo pipefail

    CERT_DIR="/etc/ssl/nix-corporate"
    TEMP_DIR=$(mktemp -d)

    echo "Extracting certificates from macOS keychain..."

    # Create certificate directory if it doesn't exist
    sudo mkdir -p "$CERT_DIR"

    # Export certificates from system keychains
    ${pkgs.darwin.security}/bin/security export -t certs -f pemseq -k /Library/Keychains/System.keychain -o "$TEMP_DIR/certs-system.pem" || true
    ${pkgs.darwin.security}/bin/security export -t certs -f pemseq -k /System/Library/Keychains/SystemRootCertificates.keychain -o "$TEMP_DIR/certs-root.pem" || true

    # Export from login keychain (where Zscaler certificates are typically installed)
    ${pkgs.darwin.security}/bin/security export -t certs -f pemseq -k ~/Library/Keychains/login.keychain-db -o "$TEMP_DIR/certs-login.pem" || true

    # Combine all certificate files
    cat "$TEMP_DIR"/*.pem > "$TEMP_DIR/ca-bundle.pem" 2>/dev/null || true

    # Only update if we have certificates
    if [[ -s "$TEMP_DIR/ca-bundle.pem" ]]; then
      echo "Found $(grep -c 'BEGIN CERTIFICATE' "$TEMP_DIR/ca-bundle.pem" || echo 0) certificates"
      sudo cp "$TEMP_DIR/ca-bundle.pem" "$CERT_DIR/ca-bundle.pem"
      sudo chmod 644 "$CERT_DIR/ca-bundle.pem"
      echo "Certificates updated at $CERT_DIR/ca-bundle.pem"

      # Update symlink for Nix if needed (though Determinate Nix handles this automatically)
      if [[ -d /nix/var/nix/profiles/default/etc/ssl/certs ]]; then
        sudo ln -sf "$CERT_DIR/ca-bundle.pem" /nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt || true
      fi
    else
      echo "No certificates found or extraction failed"
      exit 1
    fi

    # Clean up
    rm -rf "$TEMP_DIR"
  '';

  # Certificate refresh service
  certificateRefreshScript = pkgs.writeShellScript "certificate-refresh" ''
    set -euo pipefail

    echo "$(date): Starting certificate refresh..."
    if ${extractCertificates}; then
      echo "$(date): Certificate refresh completed successfully"

      # Restart relevant services that might cache certificates
      ${pkgs.darwin.launchctl}/bin/launchctl kickstart -k system/org.nixos.nix-daemon 2>/dev/null || true

      # Send notification (optional)
      ${pkgs.terminal-notifier}/bin/terminal-notifier -title "Corporate Certificates" -message "Certificates refreshed successfully" -sound default 2>/dev/null || true
    else
      echo "$(date): Certificate refresh failed"
      exit 1
    fi
  '';

  # Corporate network detection script
  detectCorporateNetwork = pkgs.writeShellScript "detect-corporate-network" ''
    set -euo pipefail

    # Check for Zscaler processes
    if pgrep -f "Zscaler" >/dev/null 2>&1; then
      echo "corporate"
      exit 0
    fi

    # Check for corporate proxy environment variables
    if [[ -n "''${HTTP_PROXY:-}" ]] || [[ -n "''${HTTPS_PROXY:-}" ]]; then
      echo "corporate"
      exit 0
    fi

    # Check for specific corporate domains in DNS
    if nslookup zscaler.net >/dev/null 2>&1; then
      echo "corporate"
      exit 0
    fi

    # Check for corporate certificate authorities in keychain
    if ${pkgs.darwin.security}/bin/security find-certificate -c "ZscalerRootCertificate" /Library/Keychains/System.keychain >/dev/null 2>&1; then
      echo "corporate"
      exit 0
    fi

    echo "personal"
  '';

in {
  options.local.zscaler = {
    enable = lib.mkEnableOption "Zscaler/corporate certificate management";

    autoDetect = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Automatically detect corporate network environment";
    };

    certificatePath = lib.mkOption {
      type = lib.types.str;
      default = "/etc/ssl/nix-corporate/ca-bundle.pem";
      description = "Path to the corporate certificate bundle";
    };

    refreshInterval = lib.mkOption {
      type = lib.types.int;
      default = 3600; # 1 hour
      description = "Certificate refresh interval in seconds";
    };

    enableNotifications = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Show notifications when certificates are updated";
    };
  };

  config = lib.mkIf cfg.enable {

    # Environment variables for system-wide SSL certificate configuration
    environment.variables = {
      # Nix-specific (though Determinate Nix handles this automatically)
      NIX_SSL_CERT_FILE = cfg.certificatePath;

      # System-wide SSL configuration
      SSL_CERT_FILE = cfg.certificatePath;
      SSL_CERT_DIR = "/etc/ssl/nix-corporate";

      # For curl and wget
      CURL_CA_BUNDLE = cfg.certificatePath;

      # For requests library (Python)
      REQUESTS_CA_BUNDLE = cfg.certificatePath;

      # For Node.js applications
      NODE_EXTRA_CA_CERTS = cfg.certificatePath;
    };

    # System activation script to set up initial certificates
    system.activationScripts.setupCorporateCertificates.text = ''
      echo >&2 "Setting up corporate certificates..."

      # Auto-detect corporate network if enabled
      ${lib.optionalString cfg.autoDetect ''
        NETWORK_TYPE=$(${detectCorporateNetwork} || echo "unknown")
        if [[ "$NETWORK_TYPE" != "corporate" ]]; then
          echo >&2 "Non-corporate network detected, skipping certificate setup"
          exit 0
        fi
      ''}

      # Extract certificates
      if ${extractCertificates}; then
        echo >&2 "Corporate certificates configured successfully"
      else
        echo >&2 "Warning: Failed to extract corporate certificates"
      fi
    '';

    # LaunchDaemon for periodic certificate refresh
    launchd.daemons.corporate-cert-refresh = {
      serviceConfig = {
        Label = "com.goonlab.corporate-cert-refresh";
        ProgramArguments = [ "${certificateRefreshScript}" ];
        StartInterval = cfg.refreshInterval;
        StandardOutPath = "/var/log/corporate-cert-refresh.log";
        StandardErrorPath = "/var/log/corporate-cert-refresh.log";
      };
    };

    # Install detection script for manual use
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "detect-corporate-network" ''
        ${detectCorporateNetwork}
      '')
      (pkgs.writeShellScriptBin "refresh-corporate-certificates" ''
        ${certificateRefreshScript}
      '')
      (pkgs.writeShellScriptBin "extract-corporate-certificates" ''
        ${extractCertificates}
      '')
    ];
  };
}