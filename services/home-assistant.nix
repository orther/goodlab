# ==============================================================================
# Home Assistant - Smart Home Automation Platform
# ==============================================================================
#
# Native NixOS module for Home Assistant with ESPHome integration.
# Used for ESPectre Wi-Fi presence detection and future home automation.
#
# Access via Cloudflare Tunnel: hass.ryatt.app → http://localhost:8123
# (configured in services/cloudflare-tunnel-noir.nix)
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
      "unifiprotect"
      "homekit_controller"
      "apple_tv"
      "lutron_caseta"

      # Network devices (auto-discovered on LAN)
      "synology_dsm"
      "brother"
      "ipp"

      # Media
      "jellyfin"
      "plex"
    ];

    config = {
      default_config = {};

      homeassistant = {
        name = "Home";
        time_zone = "America/Los_Angeles";
        unit_system = "us_customary";
        external_url = "https://hass.ryatt.app";
        # noir's LAN IP — used by HA companion app for local access
        # Update if noir's DHCP reservation changes
        internal_url = "http://10.4.0.26:8123";
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
  # ESPHome devices announce themselves via mDNS. Avahi enables the NixOS
  # host to participate in mDNS so Home Assistant can discover ESP32 devices
  # on the local network.

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  # ==========================================================================
  # Placeholder files for UI-based configuration
  # ==========================================================================
  # Home Assistant expects these YAML files to exist for the UI editors.
  # Without them, startup logs show warnings.

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
  # Open HA port on local network for direct access / Cloudflare Tunnel.
  # ESPHome Native API (port 6053) traffic comes from ESP devices on LAN.

  networking.firewall.allowedTCPPorts = [8123];

  # ==========================================================================
  # Persistence (Impermanence)
  # ==========================================================================
  # Home Assistant state, database, and configuration must survive reboots.

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
