#!/usr/bin/env bash
#
# Configure trusted-users for Nix to allow cachix substituters
# This adds the current user and admin group to trusted-users
# which allows them to use custom binary caches without warnings.
#
# For Determinate Nix: Adds setting to /etc/nix/nix.custom.conf
# For nix-darwin: Should be configured via modules/macos/base.nix (but disabled currently)
#
# Usage: sudo ./scripts/setup-nix-trusted-users.sh

set -euo pipefail

CUSTOM_CONF="/etc/nix/nix.custom.conf"

echo "Configuring Nix trusted-users..."

# Check if using Determinate Nix
if [ -f "/etc/nix/nix.conf" ] && grep -q "DETERMINATE NIX CONFIG" /etc/nix/nix.conf; then
  echo "Detected Determinate Nix installation"

  # Create or update nix.custom.conf
  if [ -f "$CUSTOM_CONF" ]; then
    # Check if trusted-users already exists
    if grep -q "^trusted-users" "$CUSTOM_CONF"; then
      echo "trusted-users already configured in $CUSTOM_CONF"
      grep "^trusted-users" "$CUSTOM_CONF"
    else
      echo "Adding trusted-users to $CUSTOM_CONF"
      echo "" >>"$CUSTOM_CONF"
      echo "# Allow members of admin group to use custom substituters" >>"$CUSTOM_CONF"
      echo "trusted-users = root @admin" >>"$CUSTOM_CONF"
      echo "✅ Added trusted-users to $CUSTOM_CONF"
    fi
  else
    echo "Creating $CUSTOM_CONF with trusted-users"
    cat >"$CUSTOM_CONF" <<EOF
# Nix custom configuration (supplements Determinate Nix managed config)
# See /etc/nix/nix.conf for main configuration

# Allow members of admin group to use custom substituters
# This resolves warnings like "ignoring untrusted substituter"
trusted-users = root @admin
EOF
    echo "✅ Created $CUSTOM_CONF with trusted-users"
  fi

  echo ""
  echo "Current nix.custom.conf contents:"
  cat "$CUSTOM_CONF"
  echo ""

  # Offer to restart the Nix daemon
  echo "Changes require restarting the Nix daemon or your shell to take effect."
  read -p "Would you like to restart the Nix daemon now? (y/n) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Restarting Nix daemon..."
    sudo launchctl kickstart -k system/org.nixos.nix-daemon
    echo "✅ Nix daemon restarted"
  else
    echo "⚠️  Remember to restart your shell or the Nix daemon for changes to take effect"
  fi

elif [ "$(uname)" = "Darwin" ]; then
  echo "This appears to be macOS without Determinate Nix"
  echo "Consider managing trusted-users via nix-darwin configuration"
  echo "See modules/macos/base.nix"
  exit 1
else
  echo "This script is for macOS with Determinate Nix"
  echo "On NixOS, configure nix.settings.trusted-users in your configuration"
  echo "See modules/nixos/base.nix"
  exit 1
fi
