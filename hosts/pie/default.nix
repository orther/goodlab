# NixOS configuration for Pie - Media Playback & Transcoding Server (2018 Mac Mini)
#
# Pie is a dedicated media playback box with hardware transcoding:
# - Jellyfin (via nixflix) with Intel Quick Sync Video (VAAPI)
# - Plex for family members
# - Apple T2 chip support via nixos-hardware
# - NFS media mount from Synology NAS
#
# All media management services (*arr stack, NZBGet, request/invite tools)
# run on noir. Pie only serves and transcodes media.
{
  inputs,
  outputs,
  lib,
  pkgs,
  ...
}: {
  imports = [
    # Apple T2 Mac support (kernel, firmware, audio)
    inputs.nixos-hardware.nixosModules.apple-t2

    # Impermanence and Home Manager
    inputs.impermanence.nixosModules.impermanence
    inputs.home-manager.nixosModules.home-manager

    # Nixflix - Declarative media server configuration
    inputs.nixflix.nixosModules.default

    # Hardware configuration
    ./hardware-configuration.nix

    # Base NixOS modules
    inputs.self.nixosModules.base

    # Services
    ./../../services/tailscale.nix
    ./../../services/nas.nix # Mounts /mnt/docker-data from NAS
    ./../../services/cloudflare-tunnel-pie.nix # Subdomain routing via Cloudflare Tunnel

    # Plex - Media server for family
    ./../../services/plex.nix
  ];

  # Home Manager configuration
  home-manager = {
    extraSpecialArgs = {inherit inputs outputs;};
    useGlobalPkgs = true;
    useUserPackages = true;
    users = {
      orther = {
        imports = [
          # Use lightweight server-base (no wrangler, nixvim, etc.)
          inputs.self.lib.hmModules.server-base
        ];

        programs.git = {
          enable = true;
          settings = {
            user = {
              name = "Brandon Orther";
              email = "brandon@orther.dev";
            };
          };
        };

        programs.ssh = {
          enable = true;
          enableDefaultConfig = false;
          matchBlocks = {
            "github.com" = {
              hostname = "github.com";
              identityFile = "~/.ssh/id_ed25519";
            };
          };
        };
      };
    };
  };

  # ==========================================================================
  # Network Configuration
  # ==========================================================================
  # Using systemd-networkd with explicit interface matching. The primary NIC
  # (enp1s0, Aquantia AQC107) is stable on this Mac Mini 2018 hardware.

  networking = {
    hostName = "pie";
    useDHCP = false;
    useNetworkd = true;

    # Disable NetworkManager in favor of simpler systemd-networkd for servers
    networkmanager.enable = lib.mkForce false;

    # Explicitly disable WiFi - Ethernet only for server reliability
    wireless.enable = false;
  };

  systemd.network = {
    enable = true;

    # Primary network interface (Aquantia 10G NIC on PCI slot 1)
    networks."10-ethernet" = {
      matchConfig.Name = "enp1s0";
      networkConfig = {
        DHCP = "yes";
        LinkLocalAddressing = "no";
      };
      dhcpV4Config = {
        UseDNS = true;
        UseRoutes = true;
      };
    };

    # Prevent systemd-networkd from managing container and virtual interfaces.
    # Without this, veth pairs, bridges, and T2 USB adapters get matched by
    # fallback rules, causing DHCP timeouts and podman networking failures.
    networks."90-unmanaged" = {
      # enp2s0f1u1 = Apple T2 iBridge USB, enp0s20f0u11i1 = HomePod USB
      matchConfig.Name = "veth* podman* enp2s0f1u1 enp0s20f0u11i1";
      linkConfig.Unmanaged = true;
    };
  };

  # Disable NetworkManager wait service (not using NetworkManager).
  # systemd-networkd-wait-online is intentionally kept enabled for network-online.target.
  systemd.services."NetworkManager-wait-online".enable = lib.mkForce false;

  # ==========================================================================
  # Intel Quick Sync Video - Hardware Transcoding
  # ==========================================================================
  # The UHD 630 (Coffee Lake) supports HEVC/H.265, H.264, VP8, VP9, and JPEG
  # hardware encoding/decoding via Intel Quick Sync Video technology.

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      # VA-API driver for Broadwell (2014) and newer - required for hardware transcoding
      # This is the modern "iHD" driver that media servers use for video encoding/decoding
      intel-media-driver

      # Intel Video Processing Library runtime
      # While officially for 11th gen+, provides broader compatibility than
      # the deprecated intel-media-sdk (which has unpatched CVEs)
      vpl-gpu-rt

      # OpenCL support for HDR tone mapping
      intel-compute-runtime
    ];
  };

  # Force the iHD VA-API driver (not the older i965 driver)
  environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";

  # Enable redistributable firmware for Intel graphics and other hardware
  hardware.enableRedistributableFirmware = true;

  # ==========================================================================
  # Apple T2 Configuration
  # ==========================================================================
  # The nixos-hardware apple-t2 module handles most T2-specific settings.

  hardware.apple-t2 = {
    # Use stable kernel channel (recommended for server stability)
    kernelChannel = "stable";

    # Enable WiFi/Bluetooth firmware (disabled since we use Ethernet only)
    firmware.enable = false;
  };

  # ==========================================================================
  # Media Directory Symlink
  # ==========================================================================
  # Create symlink for cleaner media paths:
  #   /mnt/media -> /mnt/docker-data/media
  #
  # This allows Jellyfin/Plex libraries to use:
  #   /mnt/media/movies
  #   /mnt/media/tv

  systemd.tmpfiles.rules = [
    "L+ /mnt/media - - - - /mnt/docker-data/media"
  ];

  # ==========================================================================
  # Nixflix - Declarative Media Server Configuration
  # ==========================================================================
  # Nixflix manages Jellyfin on pie. All *arr services and request management
  # have been moved to noir.

  nixflix = {
    enable = true;

    # Media directories (via NAS mount symlink)
    mediaDir = "/mnt/media";
    stateDir = "/var/lib/nixflix";

    # Users that need access to media files
    mediaUsers = ["orther" "plex"];

    # Wait for NAS mount before starting services
    serviceDependencies = ["mnt-docker\\x2ddata.mount"];

    # ========================================================================
    # Jellyfin - Primary Media Server
    # ========================================================================
    # Free, open-source, no ads, free hardware transcoding
    jellyfin = {
      enable = true;
      openFirewall = true;

      # Hardware transcoding via Intel Quick Sync (VAAPI)
      encoding.enableHardwareEncoding = true;

      # Admin user (required by nixflix)
      # Password will be set via web UI on first login
      users.admin = {
        policy.isAdministrator = true;
      };
    };
  };

  # ==========================================================================
  # Workaround: Nixflix double-slash URL bug
  # ==========================================================================
  # Nixflix constructs BASE_URL with a trailing slash when baseUrl is empty,
  # producing "http://127.0.0.1:8096//System/Info/Public" (double slash).
  # Jellyfin's Kestrel server returns 404 for double-slash paths, causing
  # silent timeouts in initialization and setup wizard services.
  # TODO: Report upstream to kiriwalawren/nixflix and remove when fixed.

  # Fix jellyfin-initialization: replace script with corrected URL
  systemd.services.jellyfin-initialization.serviceConfig.ExecStart = let
    script = pkgs.writeShellScript "jellyfin-initialization-fixed" ''
      BASE_URL="http://127.0.0.1:8096"
      echo "Waiting for Jellyfin to finish loading..."
      for i in $(seq 1 180); do
        HTTP_CODE=$(${pkgs.curl}/bin/curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/System/Info/Public" 2>/dev/null || echo "000")
        if [ "$HTTP_CODE" = "200" ]; then
          echo "Jellyfin is ready (HTTP $HTTP_CODE)"
          exit 0
        elif [ "$HTTP_CODE" = "503" ]; then
          echo "Jellyfin is still loading (HTTP 503)... attempt $i/180"
        fi
        sleep 1
      done
      echo "Jellyfin did not finish loading after 180 seconds (last HTTP code: $HTTP_CODE)" >&2
      exit 1
    '';
  in
    lib.mkForce script;

  # No-op all nixflix Jellyfin configuration services. They all source the
  # same jellyfin-auth helper which has the double-slash bug, AND the admin
  # password was set manually via the web UI (nixflix assumes empty password).
  # Jellyfin and Jellyseerr configuration is managed through their web UIs.
  systemd.services.jellyfin-setup-wizard.serviceConfig.ExecStart = lib.mkForce (pkgs.writeShellScript "jellyfin-setup-wizard-noop" ''
    echo "Jellyfin setup wizard was completed manually — skipping"
  '');
  systemd.services.jellyfin-branding-config.serviceConfig.ExecStart = lib.mkForce (pkgs.writeShellScript "jellyfin-branding-noop" ''
    echo "Jellyfin branding configured manually — skipping"
  '');
  systemd.services.jellyfin-encoding-config.serviceConfig.ExecStart = lib.mkForce (pkgs.writeShellScript "jellyfin-encoding-noop" ''
    echo "Jellyfin encoding configured manually — skipping"
  '');
  systemd.services.jellyfin-libraries.serviceConfig.ExecStart = lib.mkForce (pkgs.writeShellScript "jellyfin-libraries-noop" ''
    echo "Jellyfin libraries configured manually — skipping"
  '');
  systemd.services.jellyfin-system-config.serviceConfig.ExecStart = lib.mkForce (pkgs.writeShellScript "jellyfin-system-config-noop" ''
    echo "Jellyfin system config managed manually — skipping"
  '');
  systemd.services.jellyfin-users-config.serviceConfig.ExecStart = lib.mkForce (pkgs.writeShellScript "jellyfin-users-noop" ''
    echo "Jellyfin users configured manually — skipping"
  '');
  # ==========================================================================
  # User Configuration
  # ==========================================================================

  # GPU access for hardware transcoding (VAAPI)
  # Both media servers need video/render groups for Intel Quick Sync
  users.users.jellyfin.extraGroups = ["video" "render"];
  users.users.plex.extraGroups = ["video" "render"];

  # ==========================================================================
  # Service Persistence (Impermanence)
  # ==========================================================================
  # Persist service state across reboots

  environment.persistence."/nix/persist" = {
    directories = [
      {
        directory = "/var/lib/nixflix";
        user = "root";
        group = "root";
        mode = "0755";
      }
    ];
  };

  # ==========================================================================
  # Server Optimizations
  # ==========================================================================

  # No desktop environment needed
  services.xserver.enable = false;

  # Disable sleep/hibernate - server should always be available
  # Use mkForce to override apple-t2 module's default (which enables power management)
  powerManagement = {
    enable = lib.mkForce false;
    powertop.enable = false;
  };
  # Ignore lid events - server runs with lid closed
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchDocked = "ignore";
    HandleLidSwitchExternalPower = "ignore";
  };

  # Server-specific boot settings
  boot.loader.timeout = lib.mkForce 3; # Faster boot, less waiting (override base module's 10)
}
