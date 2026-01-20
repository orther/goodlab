# NixOS configuration for Pie Media Server on 2018 Mac Mini
#
# This configuration provides a media server with:
# - Jellyfin as the primary media server (free, open source, no ads)
# - Intel Quick Sync Video hardware transcoding
# - Apple T2 chip support via nixos-hardware
# - NFS media mount from NAS
# - Nixflix for declarative media server configuration
#
# NOTE: *arr services (Sonarr, Radarr, Prowlarr) currently run on another server.
# To enable them here later, just add: sonarr.enable = true; radarr.enable = true; etc.
#
# NOTE: Plex is included TEMPORARILY (2-4 weeks) for migration purposes.
# Family members currently use Plex clients. Once migrated to Jellyfin,
# remove the plex.nix import and users.users.plex.extraGroups line.
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

    # TEMPORARY: Plex for migration period (remove after family migrates to Jellyfin)
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
          inputs.self.lib.hmModules.base
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
  # Using systemd-networkd with match rules for robust network configuration.
  # This automatically configures any Ethernet interface, avoiding hardcoded
  # interface names that may vary between boots or hardware configurations.

  networking = {
    hostName = "pie";
    useDHCP = false;
    useNetworkd = true;

    # Disable NetworkManager in favor of simpler systemd-networkd for servers
    networkmanager.enable = lib.mkForce false;

    # Explicitly disable WiFi - Ethernet only for server reliability
    wireless.enable = false;
  };

  # Configure any Ethernet interface for DHCP via systemd-networkd
  # This is more robust than hardcoding interface names like enp0s31f6
  systemd.network = {
    enable = true;
    networks."10-ethernet" = {
      matchConfig.Type = "ether";
      networkConfig = {
        DHCP = "yes";
        # Wait for link to be configured before network-online.target
        LinkLocalAddressing = "no";
      };
      dhcpV4Config = {
        UseDNS = true;
        UseRoutes = true;
      };
    };
  };

  # Disable NetworkManager wait service (not using NetworkManager)
  # Keep systemd-networkd-wait-online enabled for proper network-online.target
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
  # Nixflix provides declarative configuration for media services.
  # Currently only Jellyfin is enabled. To add *arr services later:
  #   sonarr.enable = true;
  #   radarr.enable = true;
  #   prowlarr.enable = true;
  #   jellyseerr.enable = true;

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

    # ========================================================================
    # *arr Services - Disabled (running on separate server)
    # ========================================================================
    # Uncomment these when ready to move *arr services to this server:
    #
    # sonarr.enable = true;
    # radarr.enable = true;
    # prowlarr.enable = true;
    # jellyseerr.enable = true;
    # postgres.enable = true;  # Shared database for *arr services
  };

  # ==========================================================================
  # User Configuration
  # ==========================================================================

  # TEMPORARY: Initial password for first boot before SOPS is configured
  # This allows console/sudo access until secrets are properly set up.
  # REMOVE THIS after SOPS key is added and secrets are re-encrypted!
  # Password: "changeme" (change immediately after first login)
  users.users.orther.initialPassword = "changeme";

  # Plex needs video/render groups for hardware transcoding
  # Remove this line when removing plex.nix import
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
