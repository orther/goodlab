# NixOS configuration for Pie Media Server on 2018 Mac Mini
#
# This configuration provides a comprehensive media server stack with:
# - Jellyfin as the primary media server (free, open source, no ads)
# - *arr services for media automation (Sonarr, Radarr, Prowlarr)
# - Jellyseerr for family-friendly media requests
# - Intel Quick Sync Video hardware transcoding
# - Apple T2 chip support via nixos-hardware
# - NFS media mount from NAS
#
# NOTE: Plex is included TEMPORARILY (2-4 weeks) for migration purposes.
# Family members currently use Plex clients. Once migrated to Jellyfin,
# the plex.nix import should be removed.
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

    # Nixflix module available but not currently used
    # Using standard NixOS modules for simpler initial setup
    # inputs.nixflix.nixosModules.default

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
  networking = {
    hostName = "pie";
    useDHCP = false;
    useNetworkd = true;

    # Ethernet interface - name will be confirmed after first boot
    # Common names: enp0s31f6, eno1, enp2s0f0
    # Run `ip link` after boot to verify and update if needed
    interfaces.enp0s31f6.useDHCP = true;

    # Disable NetworkManager in favor of simpler systemd-networkd for servers
    networkmanager.enable = lib.mkForce false;

    # Explicitly disable WiFi - Ethernet only for server reliability
    wireless.enable = false;
  };

  # Disable network wait services to prevent boot hangs if network is slow
  systemd.services = {
    "NetworkManager-wait-online".enable = lib.mkForce false;
    "systemd-networkd-wait-online".enable = lib.mkForce false;
  };

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
  # Nixflix - Primary Media Stack
  # ==========================================================================
  # Nixflix provides declarative configuration for the entire media server stack.
  # Jellyfin is the primary media server (replaces Plex long-term).

  # ==========================================================================
  # Jellyfin - Primary Media Server (via standard NixOS module)
  # ==========================================================================
  # Using the standard NixOS Jellyfin module for simplicity and reliability.
  # Nixflix's API-based configuration requires secrets that must be generated
  # after first boot, making declarative setup complex.
  #
  # Free, open-source, no ads, free hardware transcoding

  services.jellyfin = {
    enable = true;
    openFirewall = true;
  };

  # ==========================================================================
  # *arr Services - Media Automation (Standard NixOS modules)
  # ==========================================================================
  # Using standard NixOS modules. These services will need manual
  # configuration after first boot via their web UIs.
  #
  # After services start, configure:
  # 1. Prowlarr (9696): Add indexers
  # 2. Radarr (7878): Configure download client, add root folder /mnt/media/movies
  # 3. Sonarr (8989): Configure download client, add root folder /mnt/media/tv
  # 4. Jellyseerr (5055): Connect to Radarr, Sonarr, and Jellyfin

  services.sonarr = {
    enable = true;
    openFirewall = true;
  };

  services.radarr = {
    enable = true;
    openFirewall = true;
  };

  services.prowlarr = {
    enable = true;
    openFirewall = true;
  };

  services.jellyseerr = {
    enable = true;
    openFirewall = true;
  };

  # ==========================================================================
  # Media Service Users - GPU Access
  # ==========================================================================
  # Both Jellyfin and Plex need video/render group membership for hardware transcoding

  users.users.jellyfin.extraGroups = ["video" "render"];
  users.users.plex.extraGroups = ["video" "render"];

  # ==========================================================================
  # Media Service Persistence
  # ==========================================================================
  # Persist service state across reboots (impermanence)

  environment.persistence."/nix/persist" = {
    directories = [
      {
        directory = "/var/lib/jellyfin";
        user = "jellyfin";
        group = "jellyfin";
        mode = "0700";
      }
      {
        directory = "/var/lib/sonarr";
        user = "sonarr";
        group = "sonarr";
        mode = "0700";
      }
      {
        directory = "/var/lib/radarr";
        user = "radarr";
        group = "radarr";
        mode = "0700";
      }
      {
        directory = "/var/lib/prowlarr";
        user = "prowlarr";
        group = "prowlarr";
        mode = "0700";
      }
      {
        directory = "/var/lib/jellyseerr";
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
  services.logind.lidSwitch = "ignore";
  services.logind.lidSwitchDocked = "ignore";
  services.logind.lidSwitchExternalPower = "ignore";

  # Server-specific boot settings
  boot.loader.timeout = 3; # Faster boot, less waiting
}
