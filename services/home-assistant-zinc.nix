# ==============================================================================
# Home Assistant - Zinc (Condo)
# ==============================================================================
#
# Home Assistant instance for the condo, running on zinc mini PC.
# Network: 192.168.1.x (router DHCP)
#
# Access via Cloudflare Tunnel: condo.ryatt.app -> http://localhost:8123
# (configured in services/cloudflare-tunnel-zinc.nix)
#
# ESPectre integration:
#   - ESP32-S3 devices run ESPectre firmware (flashed separately)
#   - Home Assistant discovers them via ESPHome Native API + mDNS
#   - Each device exposes: binary motion sensor, movement score, threshold control
#
# ==============================================================================
{...}: {
  # ==========================================================================
  # Home Assistant Service
  # ==========================================================================

  services.home-assistant = {
    enable = true;

    extraComponents = [
      # Default config bundle (includes zeroconf, ssdp, dhcp, mobile_app, etc.)
      "default_config"
      "google_translate"
      "met"
      "radio_browser"
      "shopping_list"

      # Performance
      "isal"

      # ESPectre / ESPHome presence detection
      "esphome"

      # Smart home devices
      "yale"
      "nest"
      "homekit_controller"
      "apple_tv"
      "lutron_caseta"

      # Network devices (auto-discovered on LAN)
      "brother"
      "ipp"
    ];

    config = {
      default_config = {};

      homeassistant = {
        name = "Condo";
        time_zone = "America/Los_Angeles";
        unit_system = "us_customary";
        external_url = "https://condo.ryatt.app";
        # Requires a static DHCP reservation for zinc at 192.168.1.158.
        # If the lease changes this will silently break companion app local access.
        internal_url = "http://192.168.1.158:8123";
      };

      # Allow reverse proxy (Cloudflare Tunnel)
      http = {
        use_x_forwarded_for = true;
        trusted_proxies = [
          "127.0.0.1/32"
          "::1/128"
        ];
      };

      # Ensure automations.yaml etc. exist for UI-based editing
      automation = "!include automations.yaml";
      scene = "!include scenes.yaml";
      script = "!include scripts.yaml";
    };
  };

  # ==========================================================================
  # mDNS / Avahi - Required for ESPHome device discovery
  # ==========================================================================

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  # ==========================================================================
  # Placeholder files for UI-based configuration
  # ==========================================================================

  # Write placeholder files to the persist layer directly.
  # Writing to /var/lib/hass/ would be hidden by the impermanence bind-mount.
  systemd.tmpfiles.rules = [
    "f /nix/persist/var/lib/hass/automations.yaml 0644 hass hass"
    "f /nix/persist/var/lib/hass/scenes.yaml 0644 hass hass"
    "f /nix/persist/var/lib/hass/scripts.yaml 0644 hass hass"
  ];

  # ==========================================================================
  # Firewall
  # ==========================================================================

  networking.firewall.allowedTCPPorts = [8123];

  # ==========================================================================
  # Persistence (Impermanence)
  # ==========================================================================

  environment.persistence."/nix/persist" = {
    directories = [
      {
        directory = "/var/lib/hass";
        user = "hass";
        group = "hass";
        mode = "0750";
      }
    ];
  };
}
